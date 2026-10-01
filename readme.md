# The Pyramid: Definitive Edition
A standalone, cross platform application for The Pyramid

<img width="256" height="256" alt="pyramid-icon" src="https://github.com/user-attachments/assets/21fb842e-91a6-46c2-8b17-a6ab67c16bc6" />

This is The Pyramid: Definitive Edition, an indie and roguelike roulette challenge game. The general idea is that you can draft challenge runs for games you already have. Starting as a Tabletop Simulator mod created by Olexa, The Pyramid: Definitive Edition is now a full standalone application. Draft games you want to play, then do challenges and score points in your favorite indie and roguelike games. Featuring over 100 unique and custom decks, over 2000 custom cards, 200+ games represented, and more.

Official mods for this game are located in the [official mods repo](https://github.com/codeWonderland/pyramid-mods). Local Modding is available within the game itself, as defined [in the wiki](https://github.com/codeWonderland/pyramid-definitive-edition/wiki/Official-Mods).

## Shipping new official mods in a build

The game ships with a copy of the official mods (the `initial_mods/pyramid-mods` submodule). On boot it updates players' installed mods from that copy, touching only the files that changed and downloading nothing. To put the latest mods in a build:

```bash
git -C initial_mods/pyramid-mods pull origin main
godot --headless -s tools/update_bundled_mods_manifest.gd   # records the version and its files
git add initial_mods/pyramid-mods initial_mods/pyramid-mods.json
```

A test fails if the submodule moves without the manifest being regenerated. Players with automatic updates on also get newer mods from GitHub between builds, again downloading only the files that changed.

## Steam builds and the Workshop

Steam support (Workshop publishing and subscribed packs) comes from GodotSteam in `addons/godotsteam`. Linux and Windows exports place its two libraries beside the executable, and macOS puts them inside the app, so upload the **whole export folder** to Steam. A build without those libraries, or one not started through Steam, runs normally with the Workshop buttons hidden.
