<?php
	if ( ! defined( 'ABSPATH' ) ) exit;
	
	#	WPTO Admin menu init
	add_action( 'admin_init', 'wpto_menu_init', 50 );

	function wpto_sanitize_options( $input ) {
		global $wpto;

		$fields = isset( $wpto->fields ) && is_array( $wpto->fields ) ? $wpto->fields : array();
		if ( ! is_array( $input ) ) {
			return apply_filters( 'wpto_sanitize_options', array(), $input, $fields );
		}
		if ( empty( $fields ) ) {
			return apply_filters( 'wpto_sanitize_options', $input, $input, $fields );
		}

		$sanitized = $input;
		foreach ( $fields as $section => $definition ) {
			if ( ! isset( $definition[1] ) || ! is_array( $definition[1] ) || ! isset( $input[ $section ] ) || ! is_array( $input[ $section ] ) ) {
				continue;
			}

			foreach ( $definition[1] as $slug => $field ) {
				if ( ! isset( $field[0] ) || ! array_key_exists( $slug, $input[ $section ] ) ) {
					continue;
				}

				$value = $input[ $section ][ $slug ];
				switch ( $field[0] ) {
					case 'text':
						$sanitized[ $section ][ $slug ] = is_scalar( $value ) ? sanitize_text_field( (string) $value ) : '';
						break;
					case 'email':
						$sanitized[ $section ][ $slug ] = is_scalar( $value ) ? sanitize_email( (string) $value ) : '';
						break;
					case 'textarea':
						$sanitized[ $section ][ $slug ] = is_scalar( $value ) ? sanitize_textarea_field( (string) $value ) : '';
						break;
					case 'wysiwyg':
						$sanitized[ $section ][ $slug ] = is_scalar( $value ) ? wp_kses_post( (string) $value ) : '';
						break;
					case 'checkbox':
						$sanitized[ $section ][ $slug ] = empty( $value ) ? '' : '1';
						break;
					case 'number':
						$sanitized[ $section ][ $slug ] = is_scalar( $value ) && is_numeric( (string) $value ) ? (string) $value : '';
						break;
					case 'color':
						$color = is_scalar( $value ) ? sanitize_hex_color( (string) $value ) : '';
						$sanitized[ $section ][ $slug ] = is_string( $color ) ? $color : '';
						break;
					case 'photo':
						if ( is_scalar( $value ) ) {
							$value = (string) $value;
							$sanitized[ $section ][ $slug ] = preg_match( '/^\d+$/D', $value ) ? $value : (string) absint( $value );
						} else {
							$sanitized[ $section ][ $slug ] = '';
						}
						break;
					case 'gallery':
						if ( is_scalar( $value ) ) {
							$value = (string) $value;
							if ( '' !== $value && ! preg_match( '/^\d+(?:,\d+)*,?$/D', $value ) ) {
								$trailing_comma = ',' === substr( $value, -1 );
								$attachment_ids = array_filter( array_map( 'absint', explode( ',', $value ) ) );
								$value = implode( ',', $attachment_ids );
								if ( $trailing_comma && '' !== $value ) $value .= ',';
							}
							$sanitized[ $section ][ $slug ] = $value;
						} else {
							$sanitized[ $section ][ $slug ] = '';
						}
						break;
					case 'select':
						if ( is_array( $value ) ) {
							$sanitized[ $section ][ $slug ] = array();
							foreach ( $value as $key => $selected ) {
								if ( is_scalar( $selected ) ) $sanitized[ $section ][ $slug ][ $key ] = sanitize_text_field( (string) $selected );
							}
						} elseif ( is_scalar( $value ) ) {
							$sanitized[ $section ][ $slug ] = sanitize_text_field( (string) $value );
						} else {
							$sanitized[ $section ][ $slug ] = '';
						}
						break;
				}
			}
		}

		return apply_filters( 'wpto_sanitize_options', $sanitized, $input, $fields );
	}

	function wpto_menu_init() {
		global $wpto;
		if ( ! isset( $wpto ) ) return;
			
			do_action( 'wpto_before' ) ;
			
			#	Registration settings
			if ( isset( $wpto->fields ) ) :
				register_setting( 'reading', $wpto->plugin_options_name, array( 'sanitize_callback' => 'wpto_sanitize_options' ) ) ;
				foreach ( $wpto->fields as $cat => $array ) :					
					
					add_filter( 'wpto_settings_header__' . $cat, function( $h, $cat ){ global $wpto; return $wpto->fields[$cat][0][0]; }, 5, 2 );
					add_filter( 'wpto_setting_section_before', function( $descr, $cat ){ global $wpto; $cat = str_ireplace( 'wpto_setting_section__', '', $cat ); return $wpto->fields[$cat][0][1]; }, 5, 2 );
					
					#	Adding to Settings - Reading
					add_settings_section(
						'wpto_setting_section__' . $cat,
						// phpcs:ignore WordPress.WP.I18n.NonSingularStringLiteralDomain -- The theme-derived domain is a legacy public contract.
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
		$description = apply_filters( 'wpto_setting_section_before', '', $args['id'] );
		// phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped -- Trusted extensions return complete section-description markup through this legacy filter.
		echo $description;
	}
