<h1 align="center">ServerPi Services</h1>

<p align="center">
	<a href="LICENSE"><img src="https://img.shields.io/github/license/samyarsadat/ServerPi-Services?color=blue"></a>
	|
	<a href="../../issues"><img src="https://img.shields.io/github/issues/samyarsadat/ServerPi-Services"></a>
	<br><br>
</p>

<br>

----
This repository contains Docker Compose and other configuration files for services and tools I self-host on a Raspberry Pi 4B (4GB). I have been hosting these services for almost a year now and have finally decided to make this repository public.

I've taken inspiration and learnt from many other repositories and tutorials, but I have listed all of my main sources [below](#sources--tutorials). Note that this is most likely not an exhaustive list, as I did most of my research last year and have since forgotten a lot.

Many of the services I have set up require certain "secret" variables (passwords, API keys, etc.). I store these secrets in `secrets.env` files located in the root directory of each service (the same directory that contains the `docker-compose.yaml` file). I, of course, have omitted these files from this repository, so you will have to create them yourself before running the desired service. The variables that need to be set in these `secrets.env` files are listed in `secrets.txt` files, located in the root directory of each service ([example](authelia/secrets.txt)). If there is no `secrets.txt` file in the root directory of a service, then that service has no secret variables.

I'm not going to get into the details of how everything is set up, as there are many tutorials out there explaining everything I have done here in great detail. But as a general overview, most services are reverse-proxied using Caddy and (if needed) protected by authentication using Authelia. Monitoring is done using a combination of Loki (for log collection) and Prometheus (for other statistics) and displayed using Grafana.

Services inside of the [`services`](/services) directory are all on an internal Docker network, while ones located inside of the [`external-services`](/external-services) directory are either running in `host` networking mode or don't need to be exposed to the outside world at all. Note that all websites in [`sites`](/sites) are also on the internal Docker network.

I don't actively use most of the services here, and I set them up mostly for fun, learning, and experimentation. Although I will admit, the WireGuard server has been quite useful.

<br>

### Sources & Tutorials
- [`DoTheEvo/selfhosted-apps-docker`](https://github.com/DoTheEvo/selfhosted-apps-docker)
- [Caddy & Authelia setup guide](https://caddy.community/t/securing-web-apps-with-caddy-and-authelia-in-docker-compose-an-opinionated-practical-and-minimal-production-ready-login-portal-guide/20465)
- [WordPress Docker Compose](https://github.com/docker/awesome-compose/blob/master/official-documentation-samples/wordpress/README.md)
- [DigitalOcean Tutorials](https://www.digitalocean.com/community/tutorials)

A couple of other sources which seem to be useful:
- [Techdox Docs](https://docs.techdox.nz/)
- [Dockerholics](https://github.com/petersem/dockerholics)

<br>

## Contact
You can contact me via e-mail.\
E-mail: samyarsadat@gigawhat.net

If you think that you have found a bug or issue please report it <a href="../../issues">here</a>.

<br>

## Credits
| Role       | Name                                                             |
| ---------- | ---------------------------------------------------------------- |
| Maintainer | <a href="https://github.com/samyarsadat">Samyar Sadat Akhavi</a> |

<br>
<br>

Copyright © 2024-2025 Samyar Sadat Akhavi.