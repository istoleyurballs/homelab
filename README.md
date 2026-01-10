# Homelab - Lucasfilm

Source files for my homelab, a 2 nodes kubernetes cluster running a few apps and a minecraft modded server.

<hr>

There are currently 2 nodes:
- `coruscant`: big boy x86 machine with both fast (SSD) and slow (btrfs array of hard drives) storage.
  - Its configuration can be found at `nixos/coruscant/configuration.nix`.
- `mortis`: a RPI 3B+ connected to a 3D printer.

## Instalation

Needs a working k3s cluster without traefik or local-storage.

You will need to look for the varous env files and fill them with various keys.
You can just generate random stuff for most of them.

You can find them all using:
```bash
find * -name '*.sample'
```

Once all secrets are in place, setup your `KUBECONFIG` env variable to have a working `kubectl`, then:
```bash
make up
```

Overview of the main components:
- `ingress-nginx`: as Ingress controller.
- `cert-manager`: with Lets encrpyt as issuer to manage TLS certificates.
- `lldap`+`authelia`: for authentification and securing apps.
    - TODO: don't hardcode OIDC client hashes in the config
- `prometheus`+`node-exporter`+`grafana`: as the basic monitoring stack.

Apps installed:
- `mealie`: cooking recipes database.
- `minecraft-gtnh`: a Minecraft server with the GregTech: New Horizons modpack.
- (NOT WORKING) `octoprint`:  for managing my 3D printer remotely.
