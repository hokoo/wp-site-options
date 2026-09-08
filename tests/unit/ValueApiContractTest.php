<?php

declare(strict_types=1);

namespace Hokoo\WpSiteOptions\Tests\Unit;

use Brain\Monkey;
use Brain\Monkey\Filters;
use Brain\Monkey\Functions;
use PHPUnit\Framework\TestCase;
use wpto\Theme_options;

/**
 * @see docs/source-provenance.md#value-api
 * @see docs/source-provenance.md#imported-risks-to-characterize
 */
final class ValueApiContractTest extends TestCase
{
    public static function setUpBeforeClass(): void
    {
        require_once (string) constant('WP_SITE_OPTIONS_TEST_ROOT') . '/plugin-dir/inc/classes.php';
        require_once (string) constant('WP_SITE_OPTIONS_TEST_ROOT') . '/plugin-dir/inc/functions.php';
    }

    protected function setUp(): void
    {
        parent::setUp();
        Monkey\setUp();
    }

    protected function tearDown(): void
    {
        unset($GLOBALS['wpto']);
        Monkey\tearDown();
        parent::tearDown();
    }

    public function testRawReadBypassesFilteringAndPreservesStoredGalleryString(): void
    {
        $subject = $this->createSubject(
            ['media' => ['gallery' => '10,20,30']],
            ['media' => [[], ['gallery' => ['gallery', 'Gallery']]]]
        );

        Filters\expectApplied('wpto_getoption')->never();

        self::assertSame('10,20,30', $subject->getOption('media::gallery', true));
    }

    public function testFilteredReadPassesValueCoordinatesAndDeclaredType(): void
    {
        $subject = $this->createSubject(
            ['general' => ['title' => 'Stored']],
            ['general' => [[], ['title' => ['text', 'Title']]]]
        );

        Filters\expectApplied('wpto_getoption')
            ->once()
            ->with(
                'Stored',
                ['section' => 'general', 'slug' => 'title'],
                'text'
            )
            ->andReturn('Filtered');

        self::assertSame('Filtered', $subject->getOption('general::title'));
    }

    public function testBuiltInFilterAppliesDefaultOnlyToAnEmptyString(): void
    {
        $subject = $this->createSubject(
            ['general' => ['title' => '']],
            [
                'general' => [
                    [],
                    ['title' => ['text', 'Title', ['default' => 'Fallback']]],
                ],
            ]
        );

        Filters\expectApplied('wpto_getoption')
            ->twice()
            ->andReturnUsing('wpto_getoption');

        self::assertSame('Fallback', $subject->getOption('general::title'));

        $subject->options['general']['title'] = '0';
        self::assertSame('0', $subject->getOption('general::title'));
    }

    public function testBuiltInFilterConvertsGalleryCsvWithoutTrimmingEmptySegments(): void
    {
        $subject = $this->createSubject(
            ['media' => ['gallery' => '10,20,']],
            ['media' => [[], ['gallery' => ['gallery', 'Gallery']]]]
        );

        Filters\expectApplied('wpto_getoption')
            ->once()
            ->with(
                '10,20,',
                ['section' => 'media', 'slug' => 'gallery'],
                'gallery'
            )
            ->andReturnUsing('wpto_getoption');

        self::assertSame(['10', '20', ''], $subject->getOption('media::gallery'));
    }

    public function testUndeclaredFieldUsesAnEmptyTypeWhenApplyingPublicFilter(): void
    {
        $subject = $this->createSubject(
            ['general' => ['legacy' => 'Stored']],
            ['general' => [[], []]]
        );

        Filters\expectApplied('wpto_getoption')
            ->once()
            ->with(
                'Stored',
                ['section' => 'general', 'slug' => 'legacy'],
                ''
            )
            ->andReturnFirstArg();

        self::assertSame('Stored', $subject->getOption('general::legacy'));
    }

    public function testMissingOptionReturnsNullAndEmitsLegacyArrayAccessDiagnostics(): void
    {
        $subject = $this->createSubject([], []);
        $diagnostics = [];

        set_error_handler(
            static function (int $severity, string $message) use (&$diagnostics): bool {
                $diagnostics[] = [$severity, $message];

                return true;
            }
        );

        try {
            $result = $subject->getOption('missing::field', true);
        } finally {
            restore_error_handler();
        }

        self::assertNull($result);
        self::assertNotEmpty($diagnostics, 'The imported implementation emits diagnostics for missing keys.');
        self::assertTrue(
            (bool) array_filter(
                $diagnostics,
                static function (array $diagnostic): bool {
                    return strpos($diagnostic[1], 'Undefined') !== false
                        || strpos($diagnostic[1], 'array offset') !== false;
                }
            )
        );
    }

    /**
     * @param array<string, mixed> $options
     * @param array<string, mixed> $fields
     */
    private function createSubject(array $options, array $fields): Theme_options
    {
        $theme = new class {
            public function get(string $key): string
            {
                return $key === 'TextDomain' ? 'consumer-theme' : '';
            }
        };

        Functions\when('wp_get_theme')->justReturn($theme);
        Functions\when('get_option')->justReturn($options);
        Filters\expectAdded('wpto_getoption')
            ->once()
            ->with('wpto_getoption', 10, 3);

        $subject = new Theme_options();
        $subject->fields = $fields;
        $GLOBALS['wpto'] = $subject;

        return $subject;
    }
}
