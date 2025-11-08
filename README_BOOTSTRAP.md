# NetAuto Starter v2

Contents:
- project.md / agents.md
- bootstrap.sh
- overlay/ (Elixir modules and LiveViews)
- scripts/ (route injector & migration writer)

## Quick start
```bash
tar -xzf net_auto_starter_v2.tar.gz
cd net_auto_starter_v2
./bootstrap.sh
cd net_auto
export NET_AUTO_LAB_DEFAULT_PASSWORD=changeme
mix phx.server
```
