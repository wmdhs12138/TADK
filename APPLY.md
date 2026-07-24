# Apply in Termux

```bash
cd ~/projects/TADK
rm -rf ~/tmp/tadk-alpha13-s2
mkdir -p ~/tmp/tadk-alpha13-s2
unzip -o ~/storage/downloads/TADK-0.3.0-alpha.13-sprint.2-update.zip -d ~/tmp/tadk-alpha13-s2
cp -a ~/tmp/tadk-alpha13-s2/TADK-0.3.0-alpha.13-sprint.2-update/. ~/projects/TADK/
chmod +x commands/dev.sh
bash tests/smoke.sh
```
