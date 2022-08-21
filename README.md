# nginx-monitor

To automatically monitor an NGINX server and activate CloudFlare firewall rules according to changes in the rate of active connections. To set it up you will need an API key that has permission to the said cloudflare zone. Edit the first few lines of the script to suit your setup and traffic. 

## Requirements and dependencies

- A system running GNU/Linux
- NGINX (obviously :D)
- curl
- jq
- awk

## Setup

Make sure that your NGINX has the [http_stub_status_module](https://nginx.org/en/docs/http/ngx_http_stub_status_module.html) which is usually enabled by default. You can check whether the modules is enabled via `nginx -V | grep --color -o http_stub_status`. Once you have that enabled you will need to add this server block to your NGINX config. 
If done on CentOS just create a file `/etc/nginx/conf.d/monitor.conf`:
```
server {
    listen 127.0.0.1:80;
    location /nginx_status {
        stub_status on;
        access_log off;
        allow 127.0.0.1;
        deny all;
    }
}
```
Reload the config with `nginx -t && nginx -s reload` to apply the new server block. Try to get information from the new server block to see if everything is working `curl -s 127.0.0.1/nginx_status`. This should show information about current connections to the web server. 

Setup your API key and zone ID, adjust the variables according to the amount of traffic that your server gets and just run the script to see if it is working: `sh nginx-monitor.sh`. **If you want to disable logging just leave the variable $LOG empty!**


### Creating a token
- Login & go to `https://dash.cloudflare.com/profile/api-tokens`
- Select "Create token"
- Under "Permissions" specify Zone - Firewall Services - Edit
- Under "Zone Resources" select you website.
- You can find the zone ID in the "Overview" tab of the website on Cloudflare.

## Examples
Since the script takes the running shell it would be a good idea to run it in a detached tmux or screen session. Here some exampels of how you can achieve that. 

**To run a detached screen session with the script:**`screen -dmS nginx-monitor sh nginx-monitor.sh`

**Adding the script to run atomatically on reboot:**`@reboot screen -dmS nginx-monitor sh nginx-monitor.sh`

**To attach to the script's session:**`screen -r nginx-monitor`

**To detach from the session:**`CTRL+A+D`

**To kill the session:**`CTRL+A+K`

# Links and additional info
I don't see how this can be further developed but if you have any ideas you are welcome to [join my discord](https://discord.gg/VMSDGVD) and ask for help or give me a heads up for problems with the script.





