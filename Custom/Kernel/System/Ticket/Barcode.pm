# --
# Kernel/System/Ticket/Barcode.pm - all valid functions
# Copyright (C) 2012 - 2014 Perl-Services.de, http://perl-services.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Ticket::Barcode;

use strict;
use warnings;

use GD::Barcode;

our $VERSION = 0.02;

our @ObjectDependencies = qw(
    Kernel::Config
    Kernel::System::Encode
    Kernel::System::Log
    Kernel::System::Ticket
    Kernel::System::VirtualFS
);

=head1 NAME

Kernel::System::Ticket::Barcode - utility functions for barcodes in tickets

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

create an object

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    return $Self;
}

=item BarcodeGet()

Returns information about the Barcode (path, type, attribute, ...)

=cut

sub BarcodeGet {
    my ( $Self, %Param ) = @_;

    my $LogObject    = $Kernel::OM->Get('Kernel::System::Log');
    my $DBObject     = $Kernel::OM->Get('Kernel::System::DB');
    my $TicketObject = $Kernel::OM->Get('Kernel::System::Ticket');
    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');
    my $FSObject     = $Kernel::OM->Get('Kernel::System::VirtualFS');

    for my $Needed ( qw(TicketID) ) {
        if ( !$Param{$Needed} ) {
            $LogObject->Log(
                Priority => 'error',
                Message  => "Need $Needed!",
            );
            return;
        }
    }

    my $SQL = 'SELECT b_value, b_type, barcode, b_width, b_height FROM ps_ticket_barcode '
        . 'WHERE ticket_id = ?';
    return if !$DBObject->Prepare(
        SQL   => $SQL,
        Bind  => [ \$Param{TicketID} ],
        Limit => 1,
    );

    my $BarcodeInfo; 
    while ( my @Row = $DBObject->FetchrowArray() ) {
        $BarcodeInfo = {
            Value   => $Row[0],
            Type    => $Row[1],
            Barcode => $Row[2],
            Width   => $Row[3],
            Height  => $Row[4],
        }
    }

    my %Ticket = $TicketObject->TicketGet(
        TicketID      => $Param{TicketID},
        DynamicFields => 1,
    );

    my @Queues = @{ $ConfigObject->Get('TicketBarcode::Queues') || [] };
    my $MatchedQueues = @Queues ? 0 : 1;

    for my $Queue ( @Queues ) {
        $MatchedQueues++ if $Ticket{Queue} =~ m{\A$Queue\z}xms;
    }

    return if !$MatchedQueues;

    my $ConfiguredType = $ConfigObject->Get( 'TicketBarcode::BarcodeType' ) || 'EAN13';
    my $BarcodeHeight  = $ConfigObject->Get( 'TicketBarcode::BarcodeHeight' ) || '80';
    my $Attribute      = $ConfigObject->Get( 'TicketBarcode::BarcodeAttribute' ) || 'TicketNumber';
    my $CurrentValue   = $Ticket{$Attribute};

    if ( $ConfigObject->Get( 'TicketBarcode::BarcodeTicketURL' ) ) {
        $ConfiguredType = 'QRcode';
        $CurrentValue   = sprintf "%s://%s/%sindex.pl?Action=AgentTicketZoom;TicketID=%s",
            $ConfigObject->Get( 'HttpType' ),
            $ConfigObject->Get( 'FQDN' ),
            $ConfigObject->Get( 'ScriptAlias' ),
            $Ticket{TicketID};
    }

    return if !$CurrentValue;

    my $ShallRebuild = $ConfigObject->Get( 'TicketBarcode::RebuildBarcode' );

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
        my %File = $FSObject->Read(
            Filename => $BarcodeInfo->{Barcode},
            Mode     => 'binary',
        );

        $BarcodeInfo->{Data} = ${ $File{Content} } if %File;
    }

    return $BarcodeInfo;
}

sub _BarcodeGenerate {
    my ( $Self, %Param ) = @_;

    my $LogObject    = $Kernel::OM->Get('Kernel::System::Log');
    my $DBObject     = $Kernel::OM->Get('Kernel::System::DB');
    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');
    my $FSObject     = $Kernel::OM->Get('Kernel::System::VirtualFS');

    for my $Needed ( qw(Type Value TicketID) ) {
        if ( !$Param{$Needed} ) {
            $LogObject->Log(
                Priority => 'error',
                Message  => "Need $Needed!",
            );
            return;
        }
    }

    my $Type  = $Param{Type};
    my $Value = $Param{Value};

    my $HeightConfigured = $ConfigObject->Get( 'TicketBarcode::BarcodeHeight' ) || 80;
    my %Options;

    my $Config = $ConfigObject->Get( 'TicketBarcode::' . $Type ) || {};

    if ( $Type eq 'QRcode' ) {
        %Options = (
            Ecc        => $Config->{Ecc}        || 'H',
            Version    => $Config->{Version}    || 11,
            ModuleSize => $Config->{ModuleSize} || 5,
        );
    }
    elsif ( $Type eq 'Code39' ) {
        $Value = "*$Value*";
    }

    my $BarcodeObject    = GD::Barcode->new( $Type, $Value, \%Options );

    if ( !$BarcodeObject ) {
         $LogObject->Log(
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

    my $Delete = 'DELETE FROM ps_ticket_barcode WHERE ticket_id = ?';
    $DBObject->Do(
        SQL  => $Delete,
        Bind => [ \$Param{TicketID} ],
    );

    my $SQL = 'INSERT INTO ps_ticket_barcode (ticket_id, b_value, b_type, b_width, b_height, barcode ) '
        . 'VALUES (?,?,?,?,?,?)';

    $FSObject->Delete(
        Filename => $Barcode,
    );

    $FSObject->Write(
        Content  => \$BarcodeString,
        Filename => $Barcode,
        Mode     => 'binary',
    );

    return if !$DBObject->Do(
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

