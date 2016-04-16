# --
# Kernel/Language/hu_TicketBarcode - the Hungarian translation of TicketBarcode
# Copyright (C) 2016 Perl-Services, http://www.perl-services.de
# Copyright (C) 2016 Balázs Úr, http://www.otrs-megoldasok.hu
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Language::hu_TicketBarcode;

use strict;
use warnings;

use utf8;

sub Data {
    my $Self = shift;

    my $Lang = $Self->{Translation};

    return if ref $Lang ne 'HASH';

    $Lang->{'Type of barcode generated for the tickets.'} = 'A jegyekhez előállított vonalkód típusa.';
    $Lang->{'Attribute that is encoded in the barcode.'} = 'A vonalkódba belekódolt attribútum.';
    $Lang->{'Encode ticket URL in the barcode (overrides TicketBarcode::BarcodeAttribute and only usable with QR codes).'} =
        'Jegy URL-ének belekódolása a vonalkódba (felülbírálja a TicketBarcode::BarcodeAttribute beállítást, és csak QR-kódoknál használható).';
    $Lang->{'The barcode should be rebuilt when the barcode type and/or the value of the attribute (or the attribute itself) changed.'} =
        'A vonalkódot újra elő kell-e állítani, amikor a vonalkód típusa és/vagy az attribútum értéke (vagy maga az attribútum) megváltozik.';
    $Lang->{'Height of the barcode image.'} = 'A vonalkód képének magassága.';
    $Lang->{'No'} = 'Nem';
    $Lang->{'Yes'} = 'Igen';

    return 1;
}

1;

