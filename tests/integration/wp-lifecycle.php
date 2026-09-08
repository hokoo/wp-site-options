<?php
/**
 * Real-WordPress lifecycle assertions, executed with `wp eval-file`.
 */

if ( ! defined( 'ABSPATH' ) ) {
	fwrite( STDERR, "WordPress is not loaded.\n" );
	exit( 1 );
}

/**
 * @param bool   $condition Assertion result.
 * @param string $message   Failure description.
 */
function wpso_integration_assert( $condition, $message ) {
	if ( $condition ) {
		return;
	}

	fwrite( STDERR, 'Integration assertion failed: ' . $message . "\n" );
	exit( 1 );
}

global $wpto, $wp_settings_fields, $wp_settings_sections;

wpso_integration_assert(
	isset( $wpto ) && $wpto instanceof wpto\Theme_options,
	'global $wpto must contain the public Theme_options instance'
);
wpso_integration_assert( 'wpto_options' === $wpto->plugin_options_name, 'option name changed' );
wpso_integration_assert( 'wpto_settings' === $wpto->plugin_settings_name, 'settings name changed' );

if ( ! function_exists( 'add_settings_section' ) ) {
	require_once ABSPATH . 'wp-admin/includes/template.php';
}
if ( ! function_exists( 'get_plugin_data' ) ) {
	require_once ABSPATH . 'wp-admin/includes/plugin.php';
}

wpso_integration_assert(
	50 === has_action( 'admin_init', 'wpto_menu_init' ),
	'wpto_menu_init is no longer registered on admin_init at priority 50'
);

/*
 * WP-CLI is not an admin request. Invoke the registered callback directly so
 * unrelated core admin_init callbacks do not emit false-positive diagnostics.
 */
wpto_menu_init();

$section_id = 'wpto_setting_section__local_fixture';
wpso_integration_assert(
	isset( $wp_settings_sections['reading'][ $section_id ] ),
	'fixture section was not registered on Settings -> Reading'
);
wpso_integration_assert(
	'Local development options' === $wp_settings_sections['reading'][ $section_id ]['title'],
	'fixture section title did not pass through the public filter'
);
wpso_integration_assert(
	isset( $wp_settings_fields['reading'][ $section_id ]['local_fixture-headline'] ),
	'headline field was not registered'
);

$headline_field = $wp_settings_fields['reading'][ $section_id ]['local_fixture-headline'];
wpso_integration_assert( 'wpto_echo_field' === $headline_field['callback'], 'field callback changed' );
wpso_integration_assert(
	'wpto_options[local_fixture][headline]' === $headline_field['args']['name'],
	'stored input name changed'
);

$registered_settings = get_registered_settings();
wpso_integration_assert(
	isset( $registered_settings['wpto_options'] ),
	'wpto_options was not registered with the real Settings API'
);

$stored = array(
	'local_fixture' => array(
		'headline'       => 'Persisted headline',
		'featured'       => '1',
		'items_per_page' => '12',
	),
);

wpso_integration_assert( update_option( 'wpto_options', $stored ), 'option update failed' );
wpso_integration_assert( $stored === get_option( 'wpto_options' ), 'database round trip changed data' );

$declared_fields = $wpto->fields;
$reader          = new wpto\Theme_options();
$reader->fields  = $declared_fields;
$wpto            = $reader;

wpso_integration_assert(
	'Persisted headline' === $reader->getOption( 'local_fixture::headline', true ),
	'raw public API read changed the stored value'
);
wpso_integration_assert(
	'Persisted headline' === $reader->getOption( 'local_fixture::headline' ),
	'filtered public API read changed the text value'
);
wpso_integration_assert(
	'1' === $reader->getOption( 'local_fixture::featured' ),
	'checkbox value type changed'
);
wpso_integration_assert(
	'12' === $reader->getOption( 'local_fixture::items_per_page' ),
	'number value type changed'
);

$plugin_data = get_plugin_data( WP_PLUGIN_DIR . '/wp-site-options/wp-site-options.php', false, false );

echo wp_json_encode(
	array(
		'status'             => 'pass',
		'wordpress_version'  => get_bloginfo( 'version' ),
		'php_version'        => PHP_VERSION,
		'plugin_version'     => $plugin_data['Version'],
		'registered_section' => $section_id,
		'registered_fields'  => array_keys( $wp_settings_fields['reading'][ $section_id ] ),
		'round_trip'         => $stored,
	),
	JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES
);
echo "\n";
