# killbill-kpm-plugin

Plugin to enable plugin management at runtime.

Release builds are available on [Maven Central](http://search.maven.org/#search%7Cga%7C1%7Cg%3A%22org.kill-bill.billing.plugin.ruby%22%20AND%20a%3A%22kpm-plugin%22) with coordinates `org.kill-bill.billing.plugin.ruby:kpm-plugin`.

Kill Bill compatibility
-----------------------

| KPM plugin version | Kill Bill version |
| -----------------: | ----------------: |
| 0.0.y              | 0.16.z            |
| 1.x.y              | 0.18.z            |
| 1.2.y              | 0.20.z            |

Usage
-----

* The plugin is indirectly integrated with [Kill Bill APIs](https://github.com/killbill/killbill-docs/blob/v3/userguide/tutorials/plugin_management.adoc)
* [killbill-kpm-ui](https://github.com/killbill/killbill-kpm-ui) offers a front-end for Kaui

The plugin also offers private APIs:

### Lookup plugins

All plugins:

```
curl -v \
     -u admin:password \
     http://127.0.0.1:8080/plugins/killbill-kpm/plugins
```

Specific plugin:

```
curl -v \
     -u admin:password \
     http://127.0.0.1:8080/plugins/killbill-kpm/plugins?name=stripe
```

### Plugin Management

Note that in a multi-nodes deployment, these commands would have to be run on each node. We also provide [Kill Bill apis to manage plugins](http://docs.killbill.io/0.16/plugin_management.html) that work across multi-nodes installation, but they do not allow uploading a plugin binary (e.g: jarfile), so those commands are still very useful in the context of doing plugin development.


Upload a plugin:

```
curl -v \
     -X POST \
     -u admin:password \
     -H 'Content-Type: application/json' \
     -d @/path/to/myplugin.jar \
     'http://127.0.0.1:8080/plugins/killbill-kpm/plugins?filename=myplugin.jar&key=myplugin&version=0.2.5'
```

### Uninstall a plugin

```
curl -v \
     -X DELETE \
     -u admin:password \
     'http://127.0.0.1:8080/plugins/killbill-kpm/plugins?key=myplugin&version=0.2.5'
```

### Restart a plugin

```
curl -v \
     -X PUT \
     -u admin:password \
     'http://127.0.0.1:8080/plugins/killbill-kpm/plugins?key=myplugin&version=0.2.5'
```
