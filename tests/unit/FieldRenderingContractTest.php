<?php

declare(strict_types=1);

namespace Hokoo\WpSiteOptions\Tests\Unit;

use Brain\Monkey;
use Brain\Monkey\Filters;
use Brain\Monkey\Functions;
use Mockery;
use PHPUnit\Framework\TestCase;

/**
 * @see docs/source-provenance.md#field-declaration-schema
 * @see docs/source-provenance.md#wordpress-hooks-exposed-by-the-plugin
 */
final class FieldRenderingContractTest extends TestCase
{
    public static function setUpBeforeClass(): void
    {
        require_once (string) constant('WP_SITE_OPTIONS_TEST_ROOT') . '/plugin-dir/inc/fields.php';
    }

    protected function setUp(): void
    {
        parent::setUp();
        Monkey\setUp();
        Functions\stubEscapeFunctions();
        Functions\stubTranslationFunctions();
    }

    protected function tearDown(): void
    {
        unset($GLOBALS['wpto']);
        Monkey\tearDown();
        parent::tearDown();
    }

    public function testTextFieldUsesDefaultClassesAttributesAndPublicFilters(): void
    {
        $data = [
            'cat' => 'general',
            'fullname' => 'general-title',
            'name' => 'wpto_options[general][title]',
            'slug' => 'title',
        ];
        $this->setState(
            [
                'general' => [
                    [],
                    [
                        'title' => [
                            'text',
                            'Title',
                            [
                                'default' => 'Fallback',
                                'class' => 'wide-input',
                                'attrs' => [
                                    'data-source' => 'consumer',
                                    'name' => 'must-not-replace-public-name',
                                    'oninvalid' => 'must-not-replace-validation',
                                ],
                            ],
                        ],
                    ],
                ],
            ],
            ['general' => ['title' => '']]
        );

        Filters\expectApplied('wpto_setCustomValidity_text')
            ->once()
            ->with('Please, check', 'text')
            ->andReturn('Validate text');
        Filters\expectApplied('wpto_echo_field')
            ->once()
            ->with(
                Mockery::on(
                    static function ($html): bool {
                        return is_string($html)
                            && strpos($html, 'value="Fallback"') !== false
                            && strpos($html, 'data-source="consumer"') !== false;
                    }
                ),
                $data,
                'text',
                'Fallback'
            )
            ->andReturnFirstArg();

        $html = $this->render($data);

        self::assertStringContainsString('name="wpto_options[general][title]"', $html);
        self::assertStringContainsString('type="text"', $html);
        self::assertStringContainsString('class="general-title wpto-input wide-input"', $html);
        self::assertStringContainsString("setCustomValidity( 'Validate text' )", $html);
        self::assertStringNotContainsString('must-not-replace-public-name', $html);
        self::assertStringNotContainsString('must-not-replace-validation', $html);
    }

    public function testSelectPreservesArrayNameAndExposesOptionsFilter(): void
    {
        $options = [
            ['value' => 'one', 'text' => 'One'],
            ['value' => 'two', 'text' => 'Two', 'attrs' => ['data-kind' => 'legacy']],
        ];
        $data = [
            'cat' => 'general',
            'fullname' => 'general-layout',
            'name' => 'wpto_options[general][layout]',
            'slug' => 'layout',
        ];
        $this->setState(
            [
                'general' => [
                    [],
                    [
                        'layout' => [
                            'select',
                            'Layout',
                            ['options' => $options, 'multiple' => false],
                        ],
                    ],
                ],
            ],
            ['general' => ['layout' => ['two']]]
        );

        Functions\when('selected')->alias(
            static function ($selected, $current, bool $echo = true): string {
                $markup = $selected === $current ? 'selected="selected"' : '';
                if ($echo) {
                    echo $markup;
                }

                return $markup;
            }
        );
        Filters\expectApplied('wpto:select_options')
            ->once()
            ->with(
                Mockery::on(
                    static function ($html): bool {
                        return is_string($html)
                            && strpos($html, 'value="two"') !== false
                            && strpos($html, 'selected="selected"') !== false;
                    }
                ),
                'wpto_options[general][layout]',
                $options
            )
            ->andReturn('<option data-filtered="yes">Filtered</option>');
        Filters\expectApplied('wpto_echo_field')
            ->once()
            ->with(Mockery::type('string'), $data, 'select', ['two'])
            ->andReturnFirstArg();

        $html = $this->render($data);

        self::assertStringContainsString('name="wpto_options[general][layout][]"', $html);
        self::assertStringContainsString('<option data-filtered="yes">Filtered</option>', $html);
    }

    public function testUnknownFieldTypeDelegatesToPublicCustomFieldFilter(): void
    {
        $data = [
            'cat' => 'general',
            'fullname' => 'general-custom',
            'name' => 'wpto_options[general][custom]',
            'slug' => 'custom',
        ];
        $this->setState(
            ['general' => [[], ['custom' => ['markdown', 'Custom']]]],
            ['general' => ['custom' => 'Legacy value']]
        );

        Filters\expectApplied('wpto_echo_custom_field')
            ->once()
            ->with('', $data, 'markdown', 'Legacy value')
            ->andReturn('<custom-field>Legacy value</custom-field>');
        Filters\expectApplied('wpto_echo_field')
            ->once()
            ->with('<custom-field>Legacy value</custom-field>', $data, 'markdown', 'Legacy value')
            ->andReturnFirstArg();

        self::assertSame(
            '<custom-field>Legacy value</custom-field>',
            $this->render($data)
        );
    }

    /**
     * @dataProvider mediaFieldProvider
     *
     * @param array<string, mixed> $extraExpectedArguments
     */
    public function testMediaTypesDelegateToLegacyMediaRenderer(
        string $type,
        array $extraExpectedArguments
    ): void {
        $data = [
            'cat' => 'media',
            'fullname' => 'media-' . $type,
            'name' => 'wpto_options[media][' . $type . ']',
            'slug' => $type,
        ];
        $this->setState(
            ['media' => [[], [$type => [$type, ucfirst($type)]]]],
            ['media' => [$type => '10,20']]
        );

        Functions\expect('wpto_media_modal')
            ->once()
            ->with(
                array_merge(
                    [
                        'button_id' => 'media-' . $type,
                        'option_name' => 'wpto_options[media][' . $type . ']',
                        'key' => $type,
                        'data' => '10,20',
                    ],
                    $extraExpectedArguments
                )
            );
        Filters\expectApplied('wpto_echo_field')
            ->once()
            ->with('', $data, $type, '10,20')
            ->andReturnFirstArg();

        self::assertSame('', $this->render($data));
    }

    /**
     * @return array<string, array{string, array<string, mixed>}>
     */
    public function mediaFieldProvider(): array
    {
        return [
            'photo' => ['photo', []],
            'gallery' => ['gallery', ['multiselect' => true]],
        ];
    }

    public function testAttributeHelperSuppressesProtectedNamesAndEscapesCustomValues(): void
    {
        ob_start();
        wpto_echo_attrs(
            [
                'name' => 'replacement',
                'type' => 'hidden',
                'data-label' => 'A&B',
            ]
        );
        $html = (string) ob_get_clean();

        self::assertSame('data-label="A&amp;B" ', $html);
    }

    /**
     * The imported renderer consumes a buffer created by its caller. Two levels
     * keep PHPUnit's own output capture intact while preserving that behavior.
     *
     * @param array<string, string> $data
     */
    private function render(array $data): string
    {
        $initialLevel = ob_get_level();
        ob_start();
        ob_start();

        try {
            wpto_echo_field($data);

            return (string) ob_get_clean();
        } finally {
            while (ob_get_level() > $initialLevel) {
                ob_end_clean();
            }
        }
    }

    /**
     * @param array<string, mixed> $fields
     * @param array<string, mixed> $options
     */
    private function setState(array $fields, array $options): void
    {
        $GLOBALS['wpto'] = (object) [
            'fields' => $fields,
            'options' => $options,
            'text_domain' => 'consumer-theme',
        ];
    }
}
