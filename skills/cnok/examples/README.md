# CNOK examples

The benchmark case is not copied here: it ships inside the CNOK repository that
`install_cnok.sh` clones, at `config/C/C16/1s11p.yaml`, together with the
densities `config/C/15C.den` and `config/C/12C.den`. Reproducing a deck the code
distributes is more faithful than shipping a hand-copied one, so the skill uses
the repo's own decks in place.

Run the benchmark:

```bash
bash ../scripts/run_cnok.sh 1s11p               # single config, cross sections
bash ../scripts/verify_cnok.sh                  # tier-1 check against the pinned value
```

Other decks the clone provides, usable the same way:

- `config/C/C16/{1s11p,0d55p}.yaml` and `config/C/C16/rs.yaml` (batch, ^16C -1n)
- `config/C/C15/*.yaml` (^15C -1n valence configurations)
- `config/C/C14/*.yaml`, `config/B-p/B11/*.yaml`, `config/N-p/N17/*.yaml`,
  `config/O/*` and others under `config/`.

For the field-by-field meaning of a deck see `../references/input-format.md`.
