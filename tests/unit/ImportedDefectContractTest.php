<?php

declare(strict_types=1);

namespace Hokoo\WpSiteOptions\Tests\Unit;

use PHPUnit\Framework\TestCase;

/**
 * Executable evidence for ambiguities listed in
 * docs/source-provenance.md#imported-risks-to-characterize.
 */
final class ImportedDefectContractTest extends TestCase
{
    public function testFieldRendererConsumesButDoesNotCreateAnOutputBuffer(): void
    {
        $source = file_get_contents(
            (string) constant('WP_SITE_OPTIONS_TEST_ROOT') . '/plugin-dir/inc/fields.php'
        );

        self::assertIsString($source);
        self::assertSame(1, substr_count($source, 'ob_get_contents()'));
        self::assertSame(1, substr_count($source, 'ob_end_clean()'));
        self::assertSame(0, substr_count($source, 'ob_start()'));
    }

    public function testImplementationUsesPhotoAndColorIdentifiersNotReadmeAliases(): void
    {
        $source = file_get_contents(
            (string) constant('WP_SITE_OPTIONS_TEST_ROOT') . '/plugin-dir/inc/fields.php'
        );

        self::assertIsString($source);
        self::assertMatchesRegularExpression("/case 'photo'\s*:/", $source);
        self::assertMatchesRegularExpression("/case 'color'\s*:/", $source);
        self::assertDoesNotMatchRegularExpression("/case 'image'\s*:/", $source);
        self::assertDoesNotMatchRegularExpression("/case 'colorpicker'\s*:/", $source);
    }
}
