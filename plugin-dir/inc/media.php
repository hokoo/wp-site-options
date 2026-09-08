<?php

	if ( ! defined( 'ABSPATH' ) ) exit;
	
	function wpto_media_modal( $args ){
		global $post;
		$defaults = array(
			'post_id'		=> $post->ID, 
			'button_id'		=> 'button_id_' . rand( 0, 9999 ),
			'button_text'	=> __( 'Select' ) . ' ' . __( 'Image' ),
			'multiselect'	=> false,
			'img_width'		=> 'initial',
			'data'			=> false,
			'meta_key'		=> false, 
			'key'			=> false, 
			'thumb_size'	=> 'medium', 
			//'option_name'	=> '',
		);
		$r = ( object )wp_parse_args( $args, $defaults );
		
		$r->img_width = ! empty( $r->img_width ) ? 'style="width : ' . $r->img_width . ';"' : '' ;
		?>
		<div id="<?php echo $r->button_id ?>_wrapper" class="wptoMediaModal_wrapper">
			<button class="wptoMediaModal" id="<?php echo $r->button_id ;?>" data-ids="<?php echo $r->button_id ?>_img_ids" data-preview="<?php echo $r->button_id ?>_preview" data-multiselect="<?php echo $r->multiselect ?>" ><?php echo $r->button_text ?></button><br />
			<ul class="preview clearfix" id="<?php echo $r->button_id ?>_preview" >
				<?php
				if ( $r->meta_key !== false ) :
					if ( metadata_exists( 'post', $r->post_id, $r->meta_key ) ) {
						$previews = get_post_meta( $r->post_id, $r->meta_key, TRUE );
					} ;
					$key = $r->meta_key ;
				else :
					$previews = $r->data ;
					$key = $r->key ;
				endif ;
					$attachments = array_filter( explode( ',', $previews ) );
					if ( $attachments ) {
						foreach ( $attachments as $attachment_id ) {
							echo '<li class="image" data-attachment_id="'.$attachment_id.'" ' . $r->img_width . '>'.wp_get_attachment_image( $attachment_id, $r->thumb_size ).'<span><a href="#" class="delete_slide" title="' . __( 'Delete' ) .'"></a></span></li>';					
						}
					}
				?>
			</ul>
			<input type="hidden" id="<?php echo $r->button_id ?>_img_ids" name="<?php echo $r->option_name ?>" value="<?php echo esc_attr( $previews ); ?>" />
			<br clear="all" />
		</div>
		<?php
	};

	add_action( 'admin_footer', 'wpto_media_load', 100 );
	function wpto_media_load(){
		global $wpto;
		?>
		<script type="text/javascript">
			
			( function( $ ){
				jQuery.fn.wptoMediaModal = function( options ){
					options = $.extend( {
						preview : false,
						ids : false,
						multiSelect : false,
						modalTitle : "<?php echo __( 'Select' ) . ' ' . __( 'Image' ) ?>",
						modalButton : "<?php echo __( 'Select' ) ?>",
						
						attachment_ids : "" //Задавать этот параметр не следует, он чисто технологический
					}, options );

					var make = function(){
						var slideshow_frame;							
						var $ids = jQuery( '#' + options.ids );
						var $preview = jQuery( '#' + options.preview );	
							
						// Uploading files
						jQuery( this ).live( 'click', function( event ){
					
							event.preventDefault();
							// If the media frame already exists, reopen it.
							if ( slideshow_frame ) {
								slideshow_frame.open();
								return;
							}
							// Create the media frame.
							slideshow_frame = wp.media.frames.downloadable_file = wp.media({
								title: options.modalTitle,
								button: {
									text: options.modalButton,
								},
								multiple: options.multiSelect
							});

							options.attachment_ids = $ids.val();
							// When an image is selected, run a callback.
							slideshow_frame.on( 'select', function() {
								options.attachment_ids = $ids.val();
								var selection = slideshow_frame.state().get('selection');
								selection.map( function( attachment ) {
									attachment = attachment.toJSON();
									if ( attachment.id ) {
										if ( options.multiSelect ) {
											options.attachment_ids = options.attachment_ids ? options.attachment_ids + "," + attachment.id : attachment.id;
										} else {
											options.attachment_ids = attachment.id;
											$preview.children( 'li.image' ).remove();
										};
										

										$preview.append('\
											<li class="image" data-attachment_id="' + attachment.id + '">\
												<img src="' + attachment.url + '" />\
												<span><a href="#" class="delete_slide" title="<?php _e( 'Delete image', $wpto->text_domain ); ?>"></a></span>\
											</li>');
									}
									$ids.trigger( 'selection' );
								} );
								$ids.val( options.attachment_ids );
							});
							// Finally, open the modal
							slideshow_frame.open();
						});
						// Remove files
						$preview.on( 'click', 'a.delete_slide', function() {

							jQuery( this ).closest( '.image' ).remove();
							options.attachment_ids = '';

							$preview.find( '.image' )
								.css( 'cursor','default' )
								.each( function() {
									var attachment_id = jQuery( this ).data( 'attachment_id' );
									options.attachment_ids = options.attachment_ids + attachment_id + ',';
								});

							$ids.val( options.attachment_ids );
							return false;
						} );					
					
					};

					return this.each( make ); 
				};
			})( jQuery );
			
			jQuery( document ).ready( function( $ ){
				jQuery( '.wptoMediaModal' ).each(
					function( index, element ){
						jQuery( element ).wptoMediaModal({
							ids			: jQuery( this ).data( "ids" ),
							preview		: jQuery( this ).data( "preview" ),
							multiSelect	: jQuery( this ).data( "multiselect" ),
							modalTitle	: jQuery( this ).data( "modalTitle" ),
							modalButton	: jQuery( this ).data( "modalButton" )
						});						
					}
				);
			});
		</script>
		<style>
			.wptoMediaModal{
				cursor : pointer;
			}
			.wptoMediaModal_wrapper ul.preview {
				margin: 10px 0px 0px !important;
				float : none;
			}
			.wptoMediaModal_wrapper ul.preview li.image {
				border: 0px solid #D5D5D5;
				position: relative;
				float: left;
				height: auto;
				margin: 0px 7px 7px 0px;
				cursor: move;
				border-radius: 2px;
				overflow: hidden;
			}
			#side-sortables .wptoMediaModal_wrapper ul.preview li.image {
				/*width : 100%;*/
			}
			.wptoMediaModal_wrapper ul.preview li.image img {
				width: 100%;
				height: auto;
				border-radius: 1px;	
			}
			.wptoMediaModal_wrapper ul.preview li.image {
				/*cursor: move;*/
			}	
			.wptoMediaModal_wrapper ul.preview li.image .delete_slide {
				position: absolute;
				top: 5px;
				right: 5px;
				text-indent: -9999px;
				font-family: Dashicons;
				text-decoration: none;
				cursor : pointer;
				outline : none;
			}
			.wptoMediaModal_wrapper ul.preview li.image .delete_slide:before{
				content: "\f153";
				font-size: 18px;
				width: 18px;
				height: 18px;
				color: #FFF;
				text-indent: initial;
				display: block;
				box-shadow: none;
				outline : none;
			}
			.wptoMediaModal_wrapper ul.preview li.image .delete_slide:focus:before,
			.wptoMediaModal_wrapper ul.preview li.image .delete_slide:hover:before{
				color : #AD0000;
				outline : none;
			}
		</style>		
		<?php
	};