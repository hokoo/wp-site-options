<?php
	if ( ! defined( 'ABSPATH' ) ) exit;
	
	function wpto_echo_attrs( $attrs, $stop_list = array() ){
		
		$default = array(
			'class', 'id', 'value', 'name', 'type'
		);
		$stop_list = $stop_list + $default;
		
		if ( isset( $attrs ) ) :
			foreach( $attrs as $attr => $value ) :
				if ( in_array( $attr, $stop_list ) ) continue;
				echo esc_attr( $attr ) . '="' . esc_attr( $value ) . '" ';
			endforeach;
		endif;
	}
	
	function wpto_echo_field( $data ) {
		global $wpto;

		$value = $wpto->options[ $data[ 'cat' ] ][ $data[ 'slug' ] ] ;
		if ( $value == '' && isset( $wpto->fields[ $data[ 'cat' ] ][1][ $data[ 'slug' ] ][2]['default'] ) )
			$value = $wpto->fields[ $data[ 'cat' ] ][1][ $data[ 'slug' ] ][2]['default'];
		$type = $wpto->fields[ $data[ 'cat' ] ][1][ $data[ 'slug' ] ][ 0 ];
		$clear_fullname = str_replace( array( '_', '-', ' ' ), '', $data[ 'fullname' ] );
		
		$classes = array();
		$classes[] = $data[ 'fullname' ];
		$classes[] = 'wpto-input';
		
		$html_attrs = array();
		
		#	Additional attributes
		if ( isset( $wpto->fields[ $data[ 'cat' ] ][1][ $data[ 'slug' ] ][2] ) && is_array( $wpto->fields[ $data[ 'cat' ] ][1][ $data[ 'slug' ] ][2] ) ) :
			$attrs = $wpto->fields[ $data[ 'cat' ] ][1][ $data[ 'slug' ] ][2];
			if ( isset( $attrs['class'] ) )
				$classes[] = $attrs['class'];
			
			if ( isset( $attrs['attrs'] ) )
				$html_attrs = $attrs['attrs'];
			
		endif;
		
		

		switch ( $type ) {
			case 'email' : ;
			case 'text' :
			?>
				<input 
					name="<?php echo esc_attr( $data[ 'name' ] ) ?>" 
					type="<?php echo esc_attr( $type ) ?>" 
					value="<?php echo esc_attr( $value ) ?>" 
					class="<?php echo esc_attr( implode( ' ', $classes ) ); ?>" 
					id="<?php echo esc_attr( $data[ 'fullname' ] ) ?>" 
					oninvalid="setCustomValidity( '<?php echo apply_filters( 'wpto_setCustomValidity_text', __( 'Please, check', $wpto->text_domain ), $type ); ?>' )" 
					<?php wpto_echo_attrs( $html_attrs, array( 'oninvalid' ) ); ?>
				/>	
			<?php ; break;
			case 'wysiwyg' :
				wp_editor( $value, esc_attr( $clear_fullname ), 
					array(
						'textarea_name'	=> esc_attr( $data[ 'name' ] ),
						'textarea_rows' => 7,
						'wpautop'		=> true
					) 
				);
				break;
			case 'checkbox' :
			?>
				<input 
					name="<?php echo esc_attr( $data[ 'name' ] ) ?>" 
					type="<?php echo esc_attr( $type ) ?>" 
					value="<?php echo '1' ?>" 
					class="<?php echo esc_attr( implode( ' ', $classes ) ); ?>" 
					id="<?php echo esc_attr( $data[ 'fullname' ] ) ?>" 
					<?php checked( esc_attr( $value ), '1', true ); ?> 
					<?php wpto_echo_attrs( $html_attrs, array( 'checked' ) ); ?> 
				/>	
			<?php ; break;
			case 'textarea' :
			?>
				<textarea 
					name="<?php echo esc_attr( $data['name'] ) ?>" 
					class="<?php echo esc_attr( implode( ' ', $classes ) ); ?>" 
					id="<?php echo esc_attr( $data['fullname'] ) ?>" 
					<?php wpto_echo_attrs( $html_attrs ); ?> 
				><?php echo esc_textarea( $value ) ?></textarea>
			<?php ; break;
			case 'number' :
			?>
				<input 
					name="<?php echo esc_attr( $data[ 'name' ] ) ?>" 
					type="<?php echo esc_attr( $type ) ?>" 
					value="<?php echo esc_attr( $value ) ?>" 
					class="<?php echo esc_attr( implode( ' ', $classes ) ); ?>" 
					id="<?php echo esc_attr( $data[ 'fullname' ] ) ?>" 
					oninvalid="setCustomValidity( '<?php echo apply_filters( 'wpto_setCustomValidity_text', __( 'Please, check', $wpto->text_domain ), $type ); ?>' )" 
					step=<?php echo ( isset( $attrs ) && isset( $attrs['step'] ) ) ? $attrs['step'] : 1 ; ?> 
					<?php wpto_echo_attrs( $html_attrs, array( 'oninvalid', 'step' ) ); ?>
				/>	
			<?php ; break ;	
			case 'select' :
				if ( 
						isset	( $wpto->fields[ $data[ 'cat' ] ][1][ $data[ 'slug' ] ][2]['options'] ) 
					&&	is_array( $wpto->fields[ $data[ 'cat' ] ][1][ $data[ 'slug' ] ][2]['options'] ) 
				) :
					$options = $wpto->fields[ $data[ 'cat' ] ][1][ $data[ 'slug' ] ][2]['options'];
				else :
					$options = array();
				endif;
				if ( isset( $wpto->fields[ $data[ 'cat' ] ][1][ $data[ 'slug' ] ][2]['multiple'] )  )
					$multiple = $wpto->fields[ $data[ 'cat' ] ][1][ $data[ 'slug' ] ][2]['multiple'] ? 'multiple ' : '' ;
			?>
				<select 
					name="<?php echo esc_attr( $data[ 'name' ] ) ?>[]"  
					class="<?php echo esc_attr( implode( ' ', $classes ) ); ?>" 
					id="<?php echo esc_attr( $data[ 'fullname' ] ) ?>" 
					<?php wpto_echo_attrs( $html_attrs, array( 'multiple' ) ); ?>
					<?php echo @$multiple; ?>
				><?php
					$out = '';
					$opt = '<option value="%1$s" %3$s>%2$s</option>';
					foreach( $options as $option ) :
						$attrs = '';
						if ( isset( $option['attrs'] ) && is_array( $option['attrs'] ) ) 
							foreach( $option['attrs'] as $attr => $val )
								$attrs .= $attr . '="' . $val . '" ';
						//$out .= sprintf( $opt, $option['value'], $option['text'], selected( $option['value'], $value, false ) . $attrs );
						$out .= sprintf( $opt, $option['value'], $option['text'], selected( in_array( $option['value'], $value ), true, false ) . $attrs );
					endforeach;
					$out = apply_filters( 'wpto:select_options', $out, $data[ 'name' ], $options );
					echo $out;
				?>
				</select>
			<?php ; break ;
			case 'color' : 
			?>
				<input 
					name="<?php echo esc_attr( $data[ 'name' ] ) ?>" 
					type="<?php echo esc_attr( $type ) ?>" 
					value="<?php echo esc_attr( $value ) ?>" 
					class="<?php echo esc_attr( implode( ' ', $classes ) ); ?>" 
					id="<?php echo esc_attr( $data[ 'fullname' ] ) ?>" 
					<?php wpto_echo_attrs( $html_attrs ); ?>
				/>	
			<?php ; break ;		
			case 'photo' :
				wpto_media_modal( array(
					'button_id'		=> esc_attr( $data[ 'fullname' ] ),
					'option_name'	=> esc_attr( $data[ 'name' ] ),
					'key'			=> esc_attr( $data[ 'slug' ] ),
					'data'			=> esc_attr( $value ),
					
				));
			break;
			case 'gallery' :
				wpto_media_modal( array(
					'button_id'		=> esc_attr( $data[ 'fullname' ] ),
					'multiselect'	=> true,
					'option_name'	=> esc_attr( $data[ 'name' ] ),
					'key'			=> esc_attr( $data[ 'slug' ] ),
					'data'			=> esc_attr( $value )				
				));
			break;
		default:
			echo apply_filters( 'wpto_echo_custom_field', '', $data, $type, $value );
		};
		
		$out = apply_filters( 'wpto_echo_field', ob_get_contents(), $data, $type, $value );
		ob_end_clean();
		echo $out;
	}