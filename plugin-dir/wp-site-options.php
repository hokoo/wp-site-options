<?php
/*
Plugin Name: Site Options
Plugin URI: http://nebster.net/en/plugins/site-options/
Description: Allow specify theme options
Version: 1.2.2
Requires at least: 6.0
Requires PHP: 7.4
Author: Игорь Тронь
Author URI: http://nebster.net
Domain Path: /languages
*/	
	if ( ! defined( 'ABSPATH' ) ) exit;
	
	$wpto_url = plugin_dir_url( __FILE__ ) ;
	$wpto_url = substr( $wpto_url, 0, -1 );
	$wpto_path = __DIR__ ;
	
	require( $wpto_path . '/inc/classes.php' );
	require( $wpto_path . '/inc/media.php' );
	require( $wpto_path . '/inc/fields.php' );
	require( $wpto_path . '/inc/settings.php' );
	require( $wpto_path . '/inc/functions.php' );
	
	$wpto = new wpto\Theme_options;
