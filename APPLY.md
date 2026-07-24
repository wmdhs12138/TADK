# Apply in Termux

```bash
cd ~/projects/TADK
mkdir -p ~/tmp/tadk-alpha13-s1
unzip -o ~/storage/downloads/TADK-0.3.0-alpha.13-sprint.1-update.zip \
  -d ~/tmp/tadk-alpha13-s1
cp -a \
  ~/tmp/tadk-alpha13-s1/TADK-0.3.0-alpha.13-sprint.1-update/. \
  ~/projects/TADK/
chmod +x lib/workflow.sh tests/unit/*.sh tests/smoke.sh
bash tests/unit/run.sh
bash tests/smoke.sh
```
