# qbittorrent-nox-static-cross-compile

There is a bash script for cross-compile qbittorrent-nox static for armv7l and aarch64 on Alpine 3.12, based on [musl-cross-make](https://github.com/richfelker/musl-cross-make) and [qbittorrent-nox-static](https://github.com/userdocs/qbittorrent-nox-static) :

-   Update the system and install the core build dependencies - Requires root privileges if dependencies are not present.
-   Install and build the `qbittorrent-nox` specific dependencies locally with no special privileges required.
-   Build a fully static and portable `qbittorrent-nox` binary which automatically uses the latest version of all supported dependencies.

Here is an example build profile:

```none
qBittorrent 4.3.1 was built with the following libraries:

Qt: 5.15.1
Libtorrent: 1.2.11.0
Boost: 1.74.0
OpenSSL: 1.1.1h
zlib: 1.2.11
```

Typically the script is intended to be deployed on a docker or VPS but long as your system meets the core dependency requirements tested for by the script, the script can be run as a local user.

See here for binaries I have built and how to install them - [Downloads](https://github.com/rampageX/qbittorrent-nox-static-cross-compile#download-and-install-static-builds)

## Alpine Linux platform

`musl` - This script creates a fully static `qbittorrent-nox` binary using [musl](https://wiki.musl-libc.org/).

The final result will show this when using `file`

```bash
file ./aarch64-qbittorrent-nox-4.3.1
```

Gives this result:

```bash
./aarch64-qbittorrent-nox-4.3.1: ELF 64-bit LSB executable, ARM aarch64, version 1 (SYSV), statically linked, stripped
```

## Script information

Fully static builds were built and tested on:

**Alpine Linux 3.12** amd64

## Script usage

Follow these instructions to install and use this build tool.

Use these commands via `ssh` on your Linux platform.

### For Alpine specifically, you need to install bash to use this script.

```bash
apk add bash
```

### Use [musl-cross-make](https://github.com/richfelker/musl-cross-make) build your aarch64/arm toolchain:

`make aarch64-linux-musl; make install`

`make arm-linux-musleabi; make install`

### Then execute the script use this command:

```bash
~/cb-qb-static-aarch64.sh 4.3.1 reset
```
Here `4.3.1` is qBittorrent version, `reset` for first time compile or re-compile all modules. After a full compile, if you just want compile a new version of qBittorrent next time, use:

```bash
~/cb-qb-static-aarch64.sh new-version-number
```

### Supported modules

```bash
zlib (default)
openssl (default)
boost (default)
qtbase (default)
qttools (default)
libtorrent (default)
qbittorrent (default)
```

## Download and install static builds

### Configuration

If you want to configure qBittorrent before you start it you this method

Create the default configuration directory.

```bash
mkdir -p ~/.config/qBittorrent
```

Create the configuration file.

```bash
touch ~/.config/qBittorrent/qBittorrent.conf
```

Edit the file

```bash
nano ~/.config/qBittorrent/qBittorrent.conf
```

Add this. Make sure to change your web ui port. 

```ini
[LegalNotice]
Accepted=true

[Preferences]
WebUI\Port=PORT
```


### musl static

arm64:

```bash
mkdir -p ~/bin && source ~/.profile
wget -qO ~/bin/qbittorrent-nox https://github.com/rampageX/qbittorrent-nox-static-cross-compile/releases/download/4.3.1/aarch64-qbittorrent-nox
chmod 700 ~/bin/qbittorrent-nox
```

Now you just run it and enjoy!

```bash
~/bin/qbittorrent-nox
```

Default login:

```bash
username: admin
password: adminadmin
```

Some key start-up arguments to help you along. Using the command above with no arguments will loads the defaults or the settings define in the `~/.config/qBittorrent/qBittorrent.conf`

```bash
Options:
    -v | --version             Display program version and exit
    -h | --help                Display this help message and exit
    --webui-port=<port>        Change the Web UI port
    -d | --daemon              Run in daemon-mode (background)
    --profile=<dir>            Store configuration files in <dir>
    --configuration=<name>     Store configuration files in directories
                               qBittorrent_<name>
```

### Second instance

When you simply call the binary it will look for it's configuration in `~/.config/qbittorrent`.

If you would like to run a second instance using another configuration you can do so like this

```bash
~/bin/qbittorrent-nox --configuration=NAME
```

This will create a new configuration directory using this suffix.

```bash
~/.config/qbittorrent_NAME
```

And you can now configure this instance separately.

### Nginx proxypass

```nginx
location /qbittorrent/ {
	proxy_pass http://127.0.0.1:8080/;
	proxy_http_version      1.1;
	proxy_set_header        X-Forwarded-Host        $http_host;
	http2_push_preload on; # Enable http2 push

	# The following directives effectively nullify Cross-site request forgery (CSRF)
	# protection mechanism in qBittorrent, only use them when you encountered connection problems.
	# You should consider disable "Enable Cross-site request forgery (CSRF) protection"
	# setting in qBittorrent instead of using these directives to tamper the headers.
	# The setting is located under "Options -> WebUI tab" in qBittorrent since v4.1.2.
	#proxy_hide_header       Referer;
	#proxy_hide_header       Origin;
	#proxy_set_header        Referer                 '';
	#proxy_set_header        Origin                  '';

	# Not needed since qBittorrent v4.1.0
	#add_header              X-Frame-Options         "SAMEORIGIN";
}
```

### Systemd service

Location for the systemd service file:

```bash
/etc/systemd/system/qbittorrent.service
```

Modify the path to the binary and your local username.

```ini
[Unit]

Description=qbittorrent-nox
Wants=network-online.target
After=network-online.target nss-lookup.target

[Service]

User=username
Group=username

Type=exec
WorkingDirectory=/home/username

ExecStart=/home/username/bin/qbittorrent-nox
KillMode=control-group
Restart=always
RestartSec=5
TimeoutStopSec=infinity

[Install]
WantedBy=multi-user.target
```

After any changes to the services reload using this command.

```bash
systemctl daemon-reload
```

Now you can enable the service

```bash
systemctl enable --now qbittorrent.service
```

Now you can use these commands

```bash
systemctl stop qbittorrent
systemctl start qbittorrent
systemctl restart qbittorrent
```

### Systemd local user service

You can also use a local systemd service.

```bash
~/.config/systemd/user/qbittorrent.service
```

You can use this configuration with no modification required.

```ini
[Unit]
Description=qbittorrent
After=network-online.target

[Service]
Type=simple
ExecStart=%h/bin/qbittorrent-nox

[Install]
WantedBy=default.target
```

After any changes to the services reload using this command.

```bash
systemctl --user daemon-reload
```

Now you can enable the service

```bash
systemctl --user enable --now qbittorrent.service
```

Now you can use these commands

```bash
systemctl --user stop qbittorrent
systemctl --user start qbittorrent
systemctl --user restart qbittorrent
```

## Credits

Inspired by these gists

<https://gist.github.com/notsure2>
