<?php
	if ( ! defined( 'ABSPATH' ) ) exit;
	
	function wpto_getoption( $value, $data, $type ){
		global $wpto;
		if ( $value == '' && isset( $wpto->fields[ $data[ 'section' ] ][1][ $data[ 'slug' ] ][2]['default'] ) )
			$value = $wpto->fields[ $data[ 'section' ] ][1][ $data[ 'slug' ] ][2]['default'];
		switch ( $type ) {
			case 'gallery' : 
				$value = explode( ',', $value );
				break;
			default : ;
		};
		return $value;
	}
