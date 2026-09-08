<?php
	namespace wpto;
	if ( ! defined( 'ABSPATH' ) ) exit;

	class Theme_options{
		var
			$fields,
			$options,
			$plugin_options_name,
			$plugin_settings_name,
			$text_domain;
		
		function __construct(){
			$text_domain = wp_get_theme();
			$this->text_domain = $text_domain->get( 'TextDomain' ) ;
			$this->plugin_settings_name = 'wpto_settings';
			$this->plugin_options_name = 'wpto_options';
			$this->options = get_option( $this->plugin_options_name );
			add_filter( 'wpto_getoption', 'wpto_getoption', 10, 3 );
		}
		public function getOption( $option_slug, $origin = false ){
			$o = array();
			$option_slug = explode( '::', $option_slug );
			$o[ 'section' ] = $option_slug[ 0 ];
			$o[ 'slug' ] = $option_slug[ 1 ];
			$value = $this->options[ $o[ 'section' ] ][ $o[ 'slug' ] ];
			$type = '';
			if ( isset( $this->fields[ $o[ 'section' ] ][1][ $o[ 'slug' ] ] ) )
				$type = $this->fields[ $o[ 'section' ] ][1][ $o[ 'slug' ] ][0];
			return $origin ? $value : apply_filters( 'wpto_getoption', $value, $o, $type );
		}
	}
