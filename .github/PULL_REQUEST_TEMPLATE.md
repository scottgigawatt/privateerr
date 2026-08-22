# Pull Request Boarding Pass 🏴‍☠️

## What changed? ⚓

-

## Why? 🧭

-

## Test voyage 🧪

- [ ] `make help`
- [ ] `make test`
- [ ] `make test-workflows` if workflow helpers changed
- [ ] `pre-commit run --all-files`
- [ ] `make config`
- [ ] `make build`
- [ ] `make build-buccaneerr`
- [ ] `make build-platforms` if image dependencies or build stages changed
- [ ] `make test-e2e` if VPN behavior changed
- [ ] Pinned action SHAs and Alpine digest defaults still move together
- [ ] `make clean-test` restored example config after any live test
- [ ] Any `make nuke` validation used only disposable project resources
- [ ] `git status --short` shows no generated config, logs, or other stray cargo

## Secrets check 🛡️

- [ ] No real PIA credentials
- [ ] No live `wg0.conf`
- [ ] No live `privateerr.env`
- [ ] No private logs
- [ ] Example files restored from `test/examples`

## Captain's notes 📜

-
