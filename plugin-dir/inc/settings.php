<?php
	if ( ! defined( 'ABSPATH' ) ) exit;
	
	#	WPTO Admin menu init
	add_action( 'admin_init', 'wpto_menu_init', 50 );
	function wpto_menu_init() {
		global $wpto;
		if ( ! isset( $wpto ) ) return;
			
			do_action( 'wpto_before' ) ;
			
			#	Registration settings
			if ( isset( $wpto->fields ) ) :
				register_setting( 'reading', $wpto->plugin_options_name ) ;
				foreach ( $wpto->fields as $cat => $array ) :					
					
					add_filter( 'wpto_settings_header__' . $cat, function( $h, $cat ){ global $wpto; return $wpto->fields[$cat][0][0]; }, 5, 2 );
					add_filter( 'wpto_setting_section_before', function( $descr, $cat ){ global $wpto; $cat = str_ireplace( 'wpto_setting_section__', '', $cat ); return $wpto->fields[$cat][0][1]; }, 5, 2 );
					
					#	Adding to Settings - Reading
					add_settings_section(
						'wpto_setting_section__' . $cat,
						apply_filters( 'wpto_settings_header__' . $cat, __( 'Site settings', $wpto->text_domain ), $cat ),
						'wpto_setting_section_before',
						'reading'
					);
					foreach ( $array[ 1 ] as $key => $value ) :
						$fullname = $cat . '-' . $key ;
						$name = $wpto->plugin_options_name . '[' . $cat . '][' . $key . ']' ;
						$args = array (
							'cat'		=> $cat,
							'fullname'	=> $fullname,
							'name'		=> $name,
							'slug'		=> $key,
						) ;
						
						add_settings_field( $fullname, $value[ 1 ], 'wpto_echo_field', 'reading', 'wpto_setting_section__' . $cat, $args ) ;
					endforeach;
				endforeach;
			endif;
			
			do_action( 'wpto_after' ) ;
		}
	

	function wpto_setting_section_before( $args ) {
		echo apply_filters( 'wpto_setting_section_before', '', $args['id'] );
	}