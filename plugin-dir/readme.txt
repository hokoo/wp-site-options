=== WP Site Options ===
Contributors: hokku
Donate link: https://www.paypal.me/hokku
Tags: options,site options,theme options,settings page,settings
Requires at least: 4.0
Tested up to: 6.8
Stable tag: trunc
License: GPLv2 or later
License URI: http://www.gnu.org/licenses/gpl-2.0.html

 The Site Options plugin is a simple and free product for adding your custom site options on default page Settings -> Reading. Just add a few lines in your functions file.

== Description ==

 The Site Options plugin is a simple and free product for adding your custom site options on default page Settings -> Reading.
 Just define needed settings in your functions file. [More instructions](http://nebster.net/en/plugins/site-options/ "Site Options instructions").
 
 Adding your custom options
 <pre>
	add_action( 'init', 'custom__site_options', 10 );
	function custom__site_options(){
		global $wpto;
		if ( $wpto )
		$wpto->fields = array ( 
			'section_one'	=>	array( array( 'Header - First Settings', 'description will come' ), array(
				'f_number'	=> array( 'number', 'A Number' ),
				'f_text'	=> array( 'text', 'Simple text' ),
				)),
			'section_two'	=>	array( array( 'Header - Additional settings', 'description will soon' ), array(
				'f_gallery'	=> array( 'gallery', 'Awesome gallery' ),
				'f_chbox'	=> array( 'checkbox', 'Are u checked?' ),
				)),
		);	
	}
 </pre>
 

 Access in the theme files
 <pre>
        global $wpto;
        echo $wpto->getOption( 'section_one::f_text' ) ;
 </pre>
 
= Field types support =

* text
* textarea
* wysiwyg
* checkbox
* number
* select
* email
* image
* gallery
* colorpicker

== Installation ==

1. Just setup and activate the plugin through the 'Plugins - Add' menu in WordPress

== Screenshots ==

1. Define your custom fields in your file function's.
2. Allow to Settings - Reading and specify field values.

== Frequently Asked Questions ==

= How do I create settings for my own theme? =

Please, [read instructions](http://nebster.net/en/plugins/site-options/ "Site Options instructions").

= What types options are available to use? =

* text
* textarea
* wysiwyg
* checkbox
* select
* number
* email
* image
* gallery
* colorpicker

You can define custom fieldtype by special filter, if no one this types was detected, see inc/fields.php, filter 'wpto_echo_field'.

== Changelog ==

= 1.2.1 - 05/03/17 =
* GALLERY field type henceforth return array instead string

= 1.2 - 05/03/17 =
* SELECT field type added
* Added ability to request clear field value without filtering
* Bugs fix

= 1.1 - 26/02/17 =
* Added default values