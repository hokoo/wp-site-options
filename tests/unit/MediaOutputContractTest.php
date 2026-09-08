<?php

declare(strict_types=1);

namespace Hokoo\WpSiteOptions\Tests\Unit;

use Brain\Monkey;
use Brain\Monkey\Functions;
use PHPUnit\Framework\TestCase;

/**
 * @see docs/source-provenance.md#field-declaration-schema
 * @see docs/source-provenance.md#wordpress-hooks-exposed-by-the-plugin
 * @runTestsInSeparateProcesses
 * @preserveGlobalState disabled
 */
final class MediaOutputContractTest extends TestCase
{
    protected function setUp(): void
    {
        parent::setUp();
        Monkey\setUp();
        Functions\stubEscapeFunctions();
        Functions\stubTranslationFunctions();
        Functions\when('wp_rand')->justReturn(1234);
        Functions\when('absint')->alias(
            static function ($value): int {
                return abs((int) $value);
            }
        );
        Functions\when('wp_parse_args')->alias(
            static function (array $args, array $defaults): array {
                return array_merge($defaults, $args);
            }
        );
        Functions\when('wp_get_attachment_image')->alias(
            static function (int $attachmentId, string $size): string {
                return sprintf('<img src="attachment-%d-%s.jpg" alt="" />', $attachmentId, $size);
            }
        );

        require_once (string) constant('WP_SITE_OPTIONS_TEST_ROOT') . '/plugin-dir/inc/media.php';
    }

    protected function tearDown(): void
    {
        unset($GLOBALS['post'], $GLOBALS['wpto']);
        Monkey\tearDown();
        parent::tearDown();
    }

    public function testMediaMarkupEscapesConsumerValuesAndKeepsCoreImageMarkup(): void
    {
        $GLOBALS['post'] = (object) ['ID' => 99];

        ob_start();
        wpto_media_modal([
            'button_id' => 'media" onfocus="alert(1)',
            'button_text' => '<b>Choose</b>',
            'option_name' => 'wpto_options[x]" autofocus="yes',
            'img_width' => '10"; color: red',
            'data' => '7',
            'key' => 'photo',
        ]);
        $html = (string) ob_get_clean();

        self::assertStringContainsString('id="media&quot; onfocus=&quot;alert(1)_wrapper"', $html);
        self::assertStringContainsString('&lt;b&gt;Choose&lt;/b&gt;', $html);
        self::assertStringContainsString('style="width: 10&quot;; color: red;"', $html);
        self::assertStringContainsString('<img src="attachment-7-medium.jpg" alt="" />', $html);
        self::assertStringContainsString('name="wpto_options[x]&quot; autofocus=&quot;yes"', $html);
        self::assertStringNotContainsString(' onfocus="alert(1)"', $html);
        self::assertStringNotContainsString('<b>Choose</b>', $html);
    }

    public function testMediaScriptUsesSupportedClickBindingAndThemeDomainConsumer(): void
    {
        $GLOBALS['wpto'] = (object) ['text_domain' => 'consumer-theme'];
        $translationCalls = [];
        Functions\when('__')->alias(
            static function (string $text, ?string $domain = null) use (&$translationCalls): string {
                $translationCalls[] = [$text, $domain];

                return $text;
            }
        );
        Functions\when('wp_json_encode')->alias(
            static function ($value): string {
                return (string) json_encode($value);
            }
        );

        ob_start();
        wpto_media_load();
        $script = (string) ob_get_clean();

        self::assertStringContainsString(".on( 'click'", $script);
        self::assertStringNotContainsString(".live( 'click'", $script);
        self::assertStringContainsString('modalTitle : "Select Image"', $script);
        self::assertStringContainsString('title="Delete image"', $script);
        self::assertContains(['Delete image', 'consumer-theme'], $translationCalls);
    }
}
