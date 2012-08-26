# --
# TicketBarcode.pm - code run during package de-/installation
# Copyright (C) 2012 Perl-Services.de, http://perl-services.de
#
# --
# $Id: TicketBarcode.pm,v 1.35 2012-05-08 07:37:01 ddoerffel Exp $
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --
package var::packagesetup::TicketBarcode;

use strict;
use warnings;

use Kernel::Config;
use Kernel::System::KIXUtils;

use vars qw(@ISA $VERSION);
$VERSION = qw($Revision: 1.35 $) [1];

=head1 NAME

TicketBarcode.pm - code to excecute during package installation

=head1 SYNOPSIS

All functions

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

create an object

    use Kernel::Config;
    use Kernel::System::Log;
    use Kernel::System::Main;
    use Kernel::System::Time;
    use Kernel::System::DB;
    use Kernel::System::XML;

    my $ConfigObject = Kernel::Config->new();
    my $LogObject    = Kernel::System::Log->new(
        ConfigObject => $ConfigObject,
    );
    my $MainObject = Kernel::System::Main->new(
        ConfigObject => $ConfigObject,
        LogObject    => $LogObject,
    );
    my $TimeObject = Kernel::System::Time->new(
        ConfigObject => $ConfigObject,
        LogObject    => $LogObject,
    );
    my $DBObject = Kernel::System::DB->new(
        ConfigObject => $ConfigObject,
        LogObject    => $LogObject,
        MainObject   => $MainObject,
    );
    my $XMLObject = Kernel::System::XML->new(
        ConfigObject => $ConfigObject,
        LogObject    => $LogObject,
        DBObject     => $DBObject,
        MainObject   => $MainObject,
    );
    my $CodeObject = var::packagesetup::TicketBarcode->new(
        ConfigObject => $ConfigObject,
        LogObject    => $LogObject,
        MainObject   => $MainObject,
        TimeObject   => $TimeObject,
        DBObject     => $DBObject,
        XMLObject    => $XMLObject,
    );

=cut

sub new {
    my ( $Type, %Param ) = @_;
    my $Self = {};
    bless( $Self, $Type );

    # check required params...
    for my $Object (
        qw(ConfigObject LogObject MainObject TimeObject DBObject XMLObject EncodeObject)
        )
    {
        $Self->{$Object} = $Param{$Object} || die "Got no $Object!";
    }

    # create additional objects...
    $Self->{KIXUtilsObject} = $Param{KIXUtilsObject} || Kernel::System::KIXUtils->new( %{$Self} );

    return $Self;
}

=item CodeInstall()

run the code install part

    my $Result = $CodeObject->CodeInstall();

=cut

sub CodeInstall {
    my ( $Self, %Param ) = @_;

    # register this module as custom module...
    $Self->_RegisterCustomModule();

    return 1;
}

=item CodeReinstall()

run the code reinstall part

    my $Result = $CodeObject->CodeReinstall();

=cut

sub CodeReinstall {
    my ( $Self, %Param ) = @_;

    # register this module as custom module...
    $Self->_RegisterCustomModule();

    return 1;
}

=item CodeUpgrade()

run the code upgrade part

    my $Result = $CodeObject->CodeUpgrade();

=cut

sub CodeUpgrade {
    my ( $Self, %Param ) = @_;

    # register this module as custom module...
    $Self->_RegisterCustomModule();

    return 1;
}

=item CodeUninstall()

run the code uninstall part

    my $Result = $CodeObject->CodeUninstall();

=cut

sub CodeUninstall {
    my ( $Self, %Param ) = @_;

    # unregister this module as custom module...
    $Self->_RemoveCustomModule();
    return 1;
}

#-------------------------------------------------------------------------------
# Internal functions
sub _RegisterCustomModule {
    my ( $Self, %Param ) = @_;

    #---------------------------------------------------------------------------
    # setup multiple cutsom module folders...
    # register TicketBarcode...
    $Self->{KIXUtilsObject}->RegisterCustomPackage(
        PackageName => 'TicketBarcode',
        Priority    => '0001',
    );

    #--------------------------------------------------------------------------
    # reload configuration....
    $Self->{SysConfigObject}->WriteDefault();
    my @ZZZFiles = (
        'ZZZAAuto.pm',
        'ZZZAuto.pm',
    );

    # reload the ZZZ files (mod_perl workaround)
    for my $ZZZFile (@ZZZFiles) {
        PREFIX:
        for my $Prefix (@INC) {
            my $File = $Prefix . '/Kernel/Config/Files/' . $ZZZFile;
            next PREFIX if ( !-f $File );
            do $File;
            last PREFIX;
        }
    }
    return 1;
}

sub _RemoveCustomModule {
    my ( $Self, %Param ) = @_;

    #---------------------------------------------------------------------------
    # delete all multiple cutsom module folders for TicketBarcode...
    $Self->{KIXUtilsObject}->UnRegisterCustomPackage(
        PackageName => 'TicketBarcode',
    );

    #--------------------------------------------------------------------------
    # reload configuration....
    $Self->{SysConfigObject}->WriteDefault();
    my @ZZZFiles = (
        'ZZZAAuto.pm',
        'ZZZAuto.pm',
    );

    # reload the ZZZ files (mod_perl workaround)
    for my $ZZZFile (@ZZZFiles) {
        PREFIX:
        for my $Prefix (@INC) {
            my $File = $Prefix . '/Kernel/Config/Files/' . $ZZZFile;
            next PREFIX if ( !-f $File );
            do $File;
            last PREFIX;
        }
    }
    return 1;
}

1;

=back

=head1 TERMS AND CONDITIONS

This Software is part of the OTRS project (http://otrs.org/).

This software comes with ABSOLUTELY NO WARRANTY. For details, see
the enclosed file COPYING for license information (GPL). If you
did not receive this file, see http://www.gnu.org/licenses/agpl.txt.

=cut

