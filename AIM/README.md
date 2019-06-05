# Scripts for running AIM in WIEN2k quicker

Scripts `prep_inaim_at` and `prep_inaim_charge` require atom number as an input and simply return content of `.inaim` file. To save the output, you need to redirect it to file, eg.:
```
./prep_inaim_at 1 > ${PWD##*/}.inaim
```

Script `run_aim_charge` runs AIM integration for specified list of atoms, eg.:
```
./run_aim_charge 1 4 7
```
will create input and run `x aim` for atoms 1, 4 and 7. It redirects output to `aim_out/INT_<no. of atom>` directories and produces summary for :RHOTOT and :VOLUME in `aim_report` file.

Script `run_aim_charge_all` runs AIM integration for all unequivocal atoms. It takes always first atom from the list of equivocal atoms in `.struct`. It redirects output and produces summary in the same way as `run_aim_charge`.