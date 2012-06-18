# --
# Kernel/System/Ticket/Barcode.pm - all valid functions
# Copyright (C) 2012 Perl-Services.de, http://perl-services.de
# --
# $Id: Barcode.pm,v 1.22 2011/12/23 21:39:40 reb Exp $
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Ticket::Barcode;

use strict;
use warnings;

use GD::Barcode;

use Kernel::System::VirtualFS;

use vars qw(@ISA $VERSION);
$VERSION = qw($Revision: 1.22 $) [1];

=head1 NAME

Kernel::System::Ticket::Barcode - utility functions for barcodes in tickets

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

create an object

    use Kernel::Config;
    use Kernel::System::Encode;
    use Kernel::System::Log;
    use Kernel::System::Ticket::Barcode;

    my $ConfigObject = Kernel::Config->new();
    my $EncodeObject = Kernel::System::Encode->new(
        ConfigObject => $ConfigObject,
    );
    my $LogObject = Kernel::System::Log->new(
        ConfigObject => $ConfigObject,
        EncodeObject => $EncodeObject,
    );
    my $BarcodeObject = Kernel::System::Ticket::Barcode->new(
        LogObject    => $LogObject,
        EncodeObject => $EncodeObject,
    );

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    # check needed objects
    for my $Object (qw(LogObject EncodeObject ConfigObject DBObject MainObject TicketObject)) {
        $Self->{$Object} = $Param{$Object} || die "Got no $Object!";
    }

    # create needed objects
    $Self->{VirtualFSObject} = Kernel::System::VirtualFS->new( %{$Self} );

    return $Self;
}

=item BarcodeGet()

Returns information about the Barcode (path, type, attribute, ...)

=cut

sub BarcodeGet {
    my ( $Self, %Param ) = @_;

    for my $Needed ( qw(TicketID) ) {
        if ( !$Param{$Needed} ) {
            $Self->{LogObject}->Log(
                Priority => 'error',
                Message  => "Need $Needed!",
            );
            return;
        }
    }

    my $SQL = 'SELECT b_value, b_type, barcode, b_width, b_height FROM ps_ticket_barcode '
        . 'WHERE ticket_id = ?';
    return if !$Self->{DBObject}->Prepare(
        SQL   => $SQL,
        Bind  => [ \$Param{TicketID} ],
        Limit => 1,
    );

    my $BarcodeInfo; 
    while ( my @Row = $Self->{DBObject}->FetchrowArray() ) {
        $BarcodeInfo = {
            Value   => $Row[0],
            Type    => $Row[1],
            Barcode => $Row[2],
            Width   => $Row[3],
            Height  => $Row[4],
        }
    }

    my %Ticket = $Self->{TicketObject}->TicketGet( TicketID => $Param{TicketID} );

    my $ConfiguredType = $Self->{ConfigObject}->Get( 'TicketBarcode::BarcodeType' ) || 'EAN13';
    my $BarcodeHeight  = $Self->{ConfigObject}->Get( 'TicketBarcode::BarcodeHeight' ) || '80';
    my $Attribute      = $Self->{ConfigObject}->Get( 'TicketBarcode::BarcodeAttribute' ) || 'TicketNumber';
    my $CurrentValue   = $Ticket{$Attribute};

    my $ShallRebuild   = $Self->{ConfigObject}->Get( 'TicketBarcode::RebuildBarcode' );

    if ( $ConfiguredType eq 'EAN13' ) {
        $CurrentValue = sprintf "%013d", $CurrentValue;
    } 
    elsif ( $ConfiguredType eq 'EAN8' ) {
        $CurrentValue = sprintf "%08d", $CurrentValue;
    }

    if (
        !$BarcodeInfo 
        || ( $ShallRebuild 
            && ( $ConfiguredType ne $BarcodeInfo->{Type}
                || $CurrentValue ne $BarcodeInfo->{Value}
                ) 
            )
        ) {
        $BarcodeInfo = $Self->_BarcodeGenerate(
            Type     => $ConfiguredType,
            Value    => $CurrentValue,
            TicketID => $Param{TicketID},
        );
    }
    elsif ( $BarcodeInfo ) {
        my %File = $Self->{VirtualFSObject}->Read(
            Filename => $BarcodeInfo->{Barcode},
            Mode     => 'binary',
        );

        $BarcodeInfo->{Data} = ${ $File{Content} } if %File;
    }

    return $BarcodeInfo;
}

sub _BarcodeGenerate {
    my ( $Self, %Param ) = @_;

    for my $Needed ( qw(Type Value TicketID) ) {
        if ( !$Param{$Needed} ) {
            $Self->{LogObject}->Log(
                Priority => 'error',
                Message  => "Need $Needed!",
            );
            return;
        }
    }

    my $Type  = $Param{Type};
    my $Value = $Param{Value};

    my $HeightConfigured = $Self->{ConfigObject}->Get( 'Ticket::BarcodeHeight' );
    my $BarcodeObject    = GD::Barcode->new( $Type, $Value );

    if ( !$BarcodeObject ) {
         $Self->{LogObject}->Log(
             Priority => 'error',
             Message  => $GD::Barcode::errStr,
         );
         return;
    }

    my $GDObject         = $BarcodeObject->plot( Height => $HeightConfigured );
    my $BarcodeString    = $GDObject->png;
    my ($Width, $Height) = $GDObject->getBounds;

    # if barcode image is smaller than 85% of configured height
    # and it is a QRcode than re-create it with bigger blocks
    if ( $Type eq 'QRcode' and ( $Height / $HeightConfigured ) < 0.85 ) {
        my $Blocksize     = int( $HeightConfigured / $Height );
        $BarcodeObject    = GD::Barcode->new( $Type, $Value, { ModuleSize => $Blocksize } );
        $GDObject         = $BarcodeObject->plot( Height => $HeightConfigured );
        $BarcodeString    = $GDObject->png;
        ($Width, $Height) = $GDObject->getBounds;
    }

    my $Barcode          = sprintf "Ticket/Barcode/%s.png", $Param{TicketID};

    my $Delete = 'DELETE FROM ps_ci_barcode WHERE ticket_id = ?';
    $Self->{DBObject}->Do(
        SQL  => $Delete,
        Bind => [ \$Param{TicketID} ],
    );

    my $SQL = 'INSERT INTO ps_ticket_barcode (ticket_id, b_value, b_type, b_width, b_height, barcode ) '
        . 'VALUES (?,?,?,?,?,?)';

    $Self->{VirtualFSObject}->Delete(
        Filename => $Barcode,
    );

    $Self->{VirtualFSObject}->Write(
        Content  => \$BarcodeString,
        Filename => $Barcode,
        Mode     => 'binary',
    );

    return if !$Self->{DBObject}->Do(
        SQL  => $SQL,
        Bind => [
            \$Param{TicketID},
            \$Value,
            \$Type,
            \$Width,
            \$Height,
            \$Barcode,
        ],
    );

    return {
        Type    => $Type,
        Value   => $Value,
        Width   => $Width,
        Height  => $Height,
        Barcode => $Barcode,
        Data    => $BarcodeString,
    };
}

1;

=back

=head1 TERMS AND CONDITIONS

This software comes with ABSOLUTELY NO WARRANTY. For details, see
the enclosed file COPYING for license information (AGPL). If you
did not receive this file, see L<http://www.gnu.org/licenses/agpl.txt>.

=cut

