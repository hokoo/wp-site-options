<?php
/**
 * Plugin Name: WP Site Options Local Fixture
 * Description: Registers representative fields for the local development site.
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

add_action(
	'plugins_loaded',
	static function () {
		global $wpto;

		/*
		 * WP-CLI loads WordPress from a method scope, while this legacy plugin
		 * creates its instance at file scope. Publish a local-only instance so
		 * CLI smoke commands exercise the same field declaration contract.
		 */
		if ( ! isset( $wpto ) && class_exists( 'wpto\\Theme_options' ) ) {
			$wpto = new wpto\Theme_options();
		}

		if ( ! ( $wpto instanceof wpto\Theme_options ) ) {
			return;
		}

		$fields = is_array( $wpto->fields ) ? $wpto->fields : array();
		$options = is_array( $wpto->options ) ? $wpto->options : array();

		$fields['local_fixture'] = array(
			array(
				'Local development options',
				'Representative fields registered by the local development fixture.',
			),
			array(
				'headline' => array(
					'text',
					'Headline',
					array( 'default' => 'WP Site Options local fixture' ),
				),
				'featured' => array(
					'checkbox',
					'Featured content',
				),
				'items_per_page' => array(
					'number',
					'Items per page',
					array( 'default' => 10 ),
				),
			),
		);

		$wpto->fields = $fields;
		$wpto->options = $options;
		$wpto->options['local_fixture'] = array_merge(
			array(
				'headline'       => '',
				'featured'       => '',
				'items_per_page' => '',
			),
			isset( $options['local_fixture'] ) && is_array( $options['local_fixture'] )
				? $options['local_fixture']
				: array()
		);
	}
);
