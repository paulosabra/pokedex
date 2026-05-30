# Changelog

All notable changes to this project are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Conventional Commits](https://www.conventionalcommits.org).
This file is generated from the commit history by [git-cliff](https://git-cliff.org) —
do not edit it by hand.

## [unreleased]

### Features

- Wire PRD §12 analytics events (T-30b)
- Observability seam + bootstrap (T-30a)
- Lift Search/Sort/Filters/Generations onto the whole catalogue
- Collapsible AppBar with silhouette name
- Adaptive sheets, master-detail compact list, number-range filter, shimmer skeletons
- Add error/empty state widgets + responsive layout (T-27, T-28)
- Align Detail screen with Figma 321-416
- Implement detail screen + About/Stats/Evolution tabs
- Add weight filter and align Filters/Generations with Figma
- Align Home, Sort, and Generations with Figma 218-4649
- Replace placeholder with MVVM Home screen (T-19)
- Add Gen 1 Generations sheet (T-23)
- Add Sort sheet with the four sort criteria (T-22)
- Add multi-select Filters sheet (T-21)
- Add state, ViewModel, and entity adapter (T-19/T-20)
- Refine T-18 components to Figma fidelity
- Add core design system components (T-18)
- Add use cases, DI, and routing for the domain ring (T-15 revision, T-16, T-17)
- Add domain entities + cache-first repository
- Add Drift local cache + DAO/local data source
- Add remote/network data layer (Dio, Retrofit, DTOs)
- Add design tokens and PokemonTypeTheme
- Add typed Result and Failure error vocabulary

### Bug Fixes

- Pass --token to vercel commands (T-31)
- Capture awaited boot failures in bootstrap (T-30a)
- Repair 13 failing test files on fix/tests branch
- Address 5 review-100 findings from PR #16
- Align app_colors with Figma scrim and add textNumber token
- Narrow best-effort cache-write catch to Exception
- Harden cache-first repository error paths

### Refactors

- Remove redundant pokemon detail screen responsive test
- Remove golden tests and improve golden file comparator tolerance configuration
- Replace custom tolerant comparator with LocalFileComparatorWithThreshold for improved golden test validation
- Remove unnecessary diagnostic ignore for protected member access in test configuration
- Subclass LocalFileComparator in _TolerantGoldenFileComparator to simplify golden file path management
- Trigger loadMore at exact scroll end
- Apply PR2 review fixes
- Extend PokemonFilter with generationId

### Tests

- Integration E2E + enforced coverage gate (T-29)
- Add golden image files for widget and screen visual regression testing
- Commit self-baselined goldens for the three sheets
- Refresh T-18 goldens and prune stale type-theme test

### CI/CD

- Gitignore .vercel/ linkage dir (T-31)
- Web deploy to Vercel (prebuilt) (T-31)

### Documentation

- T-31 quality review reports
- T-30b quality review reports
- T-30a quality review reports
- T-29 quality review reports
- Add quality & release brainstorm and implementation plan
- Commit hotfix review reports for fix/tests
- Commit review reports for review-100 fix sweep
- Commit review reports for full-database-coverage slice
- Add full-database coverage brainstorm and implementation plan
- Commit PR4 presentation-part4 review reports
- Commit PR3 detail-screen review reports
- Add presentation PR2 review reports
- Archive PR1 review reports into dated subfolder
- Add presentation PR1 review reports
- Add presentation layer brainstorm and implementation plan
- Add domain-layer review reports
- Update §8.3 repo snippet for findPokemon
- Add domain layer brainstorm and implementation plan
- Add data-layer PR3 review reports
- Add data-layer PR2 review reports
- Add data-layer PR1 review reports
- Add data layer brainstorm and implementation plan
- Add foundation PR3 review reports
- Add foundation PR2 review reports
- Add foundation PR1 review reports
- Add Initial Phase brainstorm and implementation plan
- Initial project documentation

### Chores

- Add observability SDKs (T-30a)
- Refresh app icons and web metadata
- Pin Flutter SDK and add golden-regeneration workflow
- Scaffold Flutter foundation with deps, codegen, lints, and CI

