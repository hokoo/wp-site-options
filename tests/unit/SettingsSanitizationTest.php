<?php

declare(strict_types=1);

namespace Hokoo\WpSiteOptions\Tests\Unit;

use Brain\Monkey;
use Brain\Monkey\Filters;
use Brain\Monkey\Functions;
use PHPUnit\Framework\TestCase;

/**
 * @see docs/source-provenance.md#field-declaration-schema
 * @see docs/source-provenance.md#wordpress-hooks-exposed-by-the-plugin
 */
final class SettingsSanitizationTest extends TestCase
{
    protected function setUp(): void
    {
        parent::setUp();
        Monkey\setUp();

        Functions\when('sanitize_text_field')->alias(
            static function (string $value): string {
                return trim(strip_tags($value));
            }
        );
        Functions\when('sanitize_email')->alias(
            static function (string $value): string {
                $sanitized = filter_var($value, FILTER_VALIDATE_EMAIL);

                return is_string($sanitized) ? $sanitized : '';
            }
        );
        Functions\when('sanitize_textarea_field')->alias(
            static function (string $value): string {
                return trim(strip_tags($value));
            }
        );
        Functions\when('wp_kses_post')->alias(
            static function (string $value): string {
                return (string) preg_replace('#<script[^>]*>.*?</script>#is', '', $value);
            }
        );
        Functions\when('sanitize_hex_color')->alias(
            static function (string $value) {
                return preg_match('/^#(?:[0-9a-fA-F]{3}){1,2}$/', $value) ? $value : null;
            }
        );
        Functions\when('absint')->alias(
            static function ($value): int {
                return abs((int) $value);
            }
        );

        require_once (string) constant('WP_SITE_OPTIONS_TEST_ROOT') . '/plugin-dir/inc/settings.php';
    }

    protected function tearDown(): void
    {
        unset($GLOBALS['wpto']);
        Monkey\tearDown();
        parent::tearDown();
    }

    public function testValidLegacyValuesRoundTripWithoutShapeChanges(): void
    {
        $fields = $this->fields();
        $input = [
            'general' => [
                'text' => 'Plain text',
                'email' => 'person@example.test',
                'textarea' => "Line one\nLine two",
                'wysiwyg' => '<p><strong>Allowed</strong></p>',
                'checkbox' => '1',
                'number' => '-12.50',
                'color' => '#AABBCC',
                'photo' => '0042',
                'gallery' => '10,020,',
                'select' => 'unlisted-scalar',
                'multi' => ['unlisted-one', 'unlisted-two'],
                'custom' => ['trusted' => '<custom-markup>'],
                'undeclared' => ['legacy' => true],
            ],
            'unknown-section' => ['payload' => '<unchanged>'],
        ];
        $GLOBALS['wpto'] = (object) ['fields' => $fields];

        Filters\expectApplied('wpto_sanitize_options')
            ->once()
            ->with($input, $input, $fields)
            ->andReturnFirstArg();

        self::assertSame($input, wpto_sanitize_options($input));
    }

    public function testMalformedStandardValuesAreSanitizedWithoutTouchingCustomData(): void
    {
        $fields = $this->fields();
        $input = [
            'general' => [
                'text' => ['raw' => '<script>bad</script>'],
                'email' => 'not-an-email',
                'textarea' => "Hello<script>alert(1)</script>\nWorld",
                'wysiwyg' => '<p>Allowed</p><script>alert(1)</script>',
                'checkbox' => ['truthy'],
                'number' => ['12'],
                'color' => 'red"><script>',
                'photo' => ['42'],
                'gallery' => '10,20<script>,oops,',
                'select' => ['safe', '<b>two</b>', ['nested' => '<raw>']],
                'multi' => '<b>scalar</b>',
                'custom' => ['trusted' => '<custom-markup>'],
                'undeclared' => ['legacy' => '<unchanged>'],
            ],
        ];
        $expected = [
            'general' => [
                'text' => '',
                'email' => '',
                'textarea' => "Helloalert(1)\nWorld",
                'wysiwyg' => '<p>Allowed</p>',
                'checkbox' => '1',
                'number' => '',
                'color' => '',
                'photo' => '',
                'gallery' => '10,20,',
                'select' => ['safe', 'two'],
                'multi' => 'scalar',
                'custom' => ['trusted' => '<custom-markup>'],
                'undeclared' => ['legacy' => '<unchanged>'],
            ],
        ];
        $GLOBALS['wpto'] = (object) ['fields' => $fields];

        Filters\expectApplied('wpto_sanitize_options')
            ->once()
            ->with($expected, $input, $fields)
            ->andReturnFirstArg();

        self::assertSame($expected, wpto_sanitize_options($input));
    }

    public function testMalformedTopLevelShapeIsRejectedBeforeTheFinalFilter(): void
    {
        $fields = $this->fields();
        $GLOBALS['wpto'] = (object) ['fields' => $fields];

        Filters\expectApplied('wpto_sanitize_options')
            ->once()
            ->with([], '<script>raw</script>', $fields)
            ->andReturnFirstArg();

        self::assertSame([], wpto_sanitize_options('<script>raw</script>'));
    }

    /**
     * @return array<string, mixed>
     */
    private function fields(): array
    {
        return [
            'general' => [
                ['General', 'Description'],
                [
                    'text' => ['text', 'Text'],
                    'email' => ['email', 'Email'],
                    'textarea' => ['textarea', 'Textarea'],
                    'wysiwyg' => ['wysiwyg', 'WYSIWYG'],
                    'checkbox' => ['checkbox', 'Checkbox'],
                    'number' => ['number', 'Number'],
                    'color' => ['color', 'Color'],
                    'photo' => ['photo', 'Photo'],
                    'gallery' => ['gallery', 'Gallery'],
                    'select' => ['select', 'Select'],
                    'multi' => ['select', 'Multi-select'],
                    'custom' => ['markdown', 'Custom'],
                ],
            ],
        ];
    }
}
