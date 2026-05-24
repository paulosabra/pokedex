# Pokédex

[![CI](https://img.shields.io/github/actions/workflow/status/paulosabra/pokedex/ci.yaml?style=for-the-badge&logo=githubactions&logoColor=white&label=CI)](https://github.com/paulosabra/pokedex/actions/workflows/ci.yaml) [![](https://img.shields.io/badge/Flutter-0553B1?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev/) [![](https://img.shields.io/badge/Claude_Code-DA7756?style=for-the-badge&logo=anthropic&logoColor=white)](https://www.anthropic.com/)

Pokédex is a simple and beautiful way to explore the world of Pokémon. It brings every creature together in one place, so anyone can look up a Pokémon and instantly discover what makes it unique — wherever they are, whether on a phone, in a browser, or on a computer.

![Pokédex project mockup](assets/presentation/project-mockup.png)

## Purpose

The goal of Pokédex is to be the friendliest and most reliable place to discover and learn about Pokémon. Whether you are a lifelong fan, a curious newcomer, or someone who just wants the right detail at the right moment, Pokédex turns a huge universe of information into something easy and enjoyable to explore.

You can browse the full collection at a glance, search by name or number, narrow things down by type or generation, and open any Pokémon to dive into its story — from its description and characteristics to its strengths and how it evolves.

Above all, Pokédex is designed to feel fast, clear, and welcoming, making it effortless for everyone to find and enjoy the Pokémon they care about.

## Getting Started

Requires the Flutter SDK (stable channel). Supported platforms: Android, iOS, Web, macOS.

```bash
# 1. Clone and enter the project
git clone https://github.com/paulosabra/pokedex.git
cd pokedex

# 2. Fetch dependencies
flutter pub get

# 3. Generate code (freezed / json_serializable / riverpod)
dart run build_runner build

# 4. Run on a device (android, ios, chrome, macos)
flutter run -d <device>
```

### Quality checks

```bash
dart format .
dart analyze --fatal-infos --fatal-warnings
flutter test --coverage
```

> **Local note:** on some hosts (observed on Flutter 3.44.0) `flutter analyze` can crash the
> analysis server. Use `dart analyze` locally; CI runs `flutter analyze` on Linux, which is the
> source of truth for analyzer results.
