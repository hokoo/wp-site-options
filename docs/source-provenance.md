# Source provenance and compatibility boundary

## Imported snapshot

- Source working copy: `/mnt/d/WP/wp-site-options`
- Repository URL: `https://plugins.svn.wordpress.org/wp-site-options`
- Repository UUID: `b8457f37-d9ea-0310-8a92-e5e31aec5664`
- Working-copy root base revision at import: `3283153`
- Mixed-revision range reported by `svnversion`: `3283153:3283155`
- Latest imported subtree change: `trunk/readme.txt` at revision `3283155`,
  author `hokku`, 2025-04-28 11:29:59 +0400
- The plugin root and `trunk/` directory nodes last changed at revision `1608075`;
  that directory-level value does not include later descendant changes and is
  therefore not used as the snapshot's latest-change claim.
- SVN status at import: clean
- Imported Git commit: `640615d`
- `trunk/` destination: `plugin-dir/`
- `assets/` destination: `.wordpress-org/`
- Historical `tags/` and `.svn/` metadata: intentionally not imported
- SHA-256 manifest: [`svn-snapshot.sha256`](./svn-snapshot.sha256)

The Git blobs for every imported file were compared with the corresponding SVN working-copy file after staging and again after commit. Line endings are preserved through `.gitattributes`. File modes are `0644`: the Windows mount exposed every source file as executable, while SVN has no `svn:executable` properties. Binary assets retain their SVN MIME-type role; the deployment task restores the corresponding SVN MIME properties.

## Snapshot integrity procedure

1. Require an empty `svn status` for the working-copy root.
2. Compare `trunk/` with `plugin-dir/` and `assets/` with `.wordpress-org/`, excluding `.svn` only.
3. Recalculate every path in `svn-snapshot.sha256`.
4. Compare the SHA-256 of every committed Git blob with the corresponding SVN file.
5. Confirm that `.svn`, local configs, credentials, dumps, logs, and archives are absent from the Git index.

## Public compatibility boundary

The first maintenance cycle may fix compatibility and security defects, but it must preserve the contracts below unless the owner approves a new decision gate.

### Bootstrap and global state

| Contract | Legacy behavior | Source |
|---|---|---|
| `$wpto` | A global `wpto\Theme_options` instance is created while the plugin entrypoint is loaded. | `plugin-dir/wp-site-options.php` |
| `$wpto_url` | Global plugin URL without its trailing slash. | `plugin-dir/wp-site-options.php` |
| `$wpto_path` | Global absolute plugin directory path. | `plugin-dir/wp-site-options.php` |
| `wpto\Theme_options::$fields` | Consumer-defined field schema, normally assigned by a theme before `admin_init` priority 50. | `plugin-dir/inc/classes.php`, `plugin-dir/inc/settings.php` |
| `wpto\Theme_options::$options` | Snapshot of the `wpto_options` option loaded by the constructor. | `plugin-dir/inc/classes.php` |
| `plugin_options_name` | Literal `wpto_options`. | `plugin-dir/inc/classes.php` |
| `plugin_settings_name` | Literal `wpto_settings`; retained even though registration uses the option name. | `plugin-dir/inc/classes.php` |
| `text_domain` | Derived from the active theme `TextDomain`, not from a plugin text domain. | `plugin-dir/inc/classes.php` |

### Field declaration schema

The documented consumer shape is:

```php
$wpto->fields = array(
    'section_slug' => array(
        array('Section title', 'Section description'),
        array(
            'field_slug' => array('type', 'Field label', array(/* options/attrs/default */)),
        ),
    ),
);
```

Settings are registered on the native `reading` settings group/page. Stored input names follow `wpto_options[section_slug][field_slug]`; section IDs follow `wpto_setting_section__<section>` and field IDs follow `<section>-<field>`.

Implemented field type identifiers are `email`, `text`, `wysiwyg`, `checkbox`, `textarea`, `number`, `select`, `color`, `photo`, and `gallery`. Unknown identifiers delegate to `wpto_echo_custom_field`. The WordPress.org readme currently says `image` and `colorpicker`, whereas the implementation switches on `photo` and `color`; this mismatch is an imported defect, not a new alias contract.

The optional third field element supports:

- `default` for empty stored values;
- `class` appended to generated input classes;
- `attrs` rendered as additional HTML attributes except protected attributes;
- `options` for select option records;
- `multiple` for select behavior;
- `step` for number fields.

### Value API

`wpto\Theme_options::getOption($option_slug, $origin = false)` accepts an identifier formatted as `section::field`.

- With `$origin === true`, it returns the stored value directly and bypasses `wpto_getoption` processing.
- Otherwise it applies `wpto_getoption` with the value, parsed section/slug data, and declared field type.
- An empty-string value uses the configured `default`, if present.
- A `gallery` value is stored as comma-separated IDs and returned as an array after filtering.
- Existing missing-section/missing-field accesses may emit PHP warnings; safe handling is a compatibility finding to characterize before remediation.

### WordPress hooks exposed by the plugin

| Kind | Hook | Arguments/behavior |
|---|---|---|
| action | `admin_init` | Registers `wpto_menu_init` at priority 50. |
| action | `admin_footer` | Registers `wpto_media_load` at priority 100. |
| action | `wpto_before` | Fired before settings registration, no explicit arguments. |
| action | `wpto_after` | Fired after settings registration, no explicit arguments. |
| filter | `wpto_getoption` | `(value, array{section,slug}, type)`; the built-in callback supplies defaults and gallery conversion. |
| filter | `wpto_settings_header__<section>` | `(fallback_title, section_slug)`; determines a section title. |
| filter | `wpto_setting_section_before` | `(description, section_id)`; determines section description output. |
| filter | `wpto_setCustomValidity_text` | `(translated_message, field_type)` for text/email/number validation text. |
| filter | `wpto:select_options` | `(options_html, field_name, options)` before select HTML is emitted. |
| filter | `wpto_echo_custom_field` | `('', field_data, type, value)` for an unknown field type. |
| filter | `wpto_echo_field` | `(captured_html, field_data, type, value)` around final field output. |
| filter | `wpto_sanitize_options` | `(sanitized_options, original_input, fields)` after type-aware sanitization; trusted integrations may adjust the final stored value. |

### Global callable functions

- `wpto_getoption($value, $data, $type)`
- `wpto_menu_init()`
- `wpto_sanitize_options($input)`
- `wpto_setting_section_before($args)`
- `wpto_echo_attrs($attrs, $stop_list = array())`
- `wpto_echo_field($data)`
- `wpto_media_modal($args)`
- `wpto_media_load()`

They are not namespaced and may be called or filtered by existing integrations. Compatibility fixes should retain names and accepted arguments.

## Difference from the last SVN tag

The last historical SVN tag is `1.2`; SVN trunk identifies itself as `1.2.1`, but no `tags/1.2.1` exists.

Changes from `tags/1.2` to the imported trunk are limited to:

- plugin header `1.2` → `1.2.1`;
- `wpto_getoption` callback/filter arity from two to three arguments;
- propagation of the field type into the value filter;
- `gallery` conversion from a comma-separated string to an array;
- readme `Tested up to` from `4.7.2` to `6.8`;
- a `1.2.1` changelog entry.

`Stable tag: trunc` is present in both tag `1.2` and trunk, so it is a pre-existing metadata defect. The approved first automated release is `1.2.2`, which will normalize the stable tag and minimum requirements without creating a retrospective `1.2.1` tag.

## Imported risks to characterize

These are the original imported findings. Resolved items are linked to the T13 evidence; the remaining items are compatibility risks, not approved behavior changes:

- direct nested-array access can emit warnings for empty or partially configured options;
- field rendering formerly consumed a caller-owned output buffer; resolved in [`qa/t13-remediation.md`](./qa/t13-remediation.md);
- media JavaScript formerly used the removed jQuery `.live()` API; resolved in [`qa/t13-remediation.md`](./qa/t13-remediation.md);
- select rendering assumes an array value and renders `[]` even for a single select;
- settings registration formerly had no explicit sanitization callback; resolved in [`qa/t13-remediation.md`](./qa/t13-remediation.md);
- output escaping findings were remediated while preserving trusted raw-HTML filter boundaries; see [`qa/t13-remediation.md`](./qa/t13-remediation.md);
- readme field identifiers disagree with implementation identifiers;
- localization follows the active theme text domain.

Characterization tests must decide which observable behavior is contractual before a release-blocking finding is changed.
