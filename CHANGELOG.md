# Changelog

## [0.19.0](https://github.com/YouTogether/youtogether-frontend/compare/v0.18.0...v0.19.0) (2026-09-05)


### Features

* **auth:** [F-A06-T1] Add the Firebase session port and use cases ([#116](https://github.com/YouTogether/youtogether-frontend/issues/116)) ([bc4f4f8](https://github.com/YouTogether/youtogether-frontend/commit/bc4f4f84d143a6f0fb780b611a02e36446da71df))
* **auth:** [F-A06-T2] Implement the Firebase session data layer ([#117](https://github.com/YouTogether/youtogether-frontend/issues/117)) ([1351883](https://github.com/YouTogether/youtogether-frontend/commit/1351883f010831fedea977ebc7f61cc663f430a3))
* **auth:** [F-A06-T3] Gate room entry on an established Firebase session ([#118](https://github.com/YouTogether/youtogether-frontend/issues/118)) ([aa385db](https://github.com/YouTogether/youtogether-frontend/commit/aa385db92a1ca58ab713e9ba3e830c9a56b33421))
* **room:** [F-R03-T3] edit room cancel button ([#99](https://github.com/YouTogether/youtogether-frontend/issues/99)) ([9a17bcd](https://github.com/YouTogether/youtogether-frontend/commit/9a17bcdc717fa4e556c5dc852da7ddc6be3fc996))
* **video-sync:** [F-V01-T1] Embed the YouTube IFrame player ([#106](https://github.com/YouTogether/youtogether-frontend/issues/106)) ([491e178](https://github.com/YouTogether/youtogether-frontend/commit/491e178b0b76636d736db0fb525d2cc623e618c3))
* **video-sync:** [F-V02-T1] Define playback domain layer ([#101](https://github.com/YouTogether/youtogether-frontend/issues/101)) ([0eacfec](https://github.com/YouTogether/youtogether-frontend/commit/0eacfec7be3da3a5b6914d9b7d933a745d612e1e))
* **video-sync:** [F-V02-T2] Implement Firebase data source for playback state ([#104](https://github.com/YouTogether/youtogether-frontend/issues/104)) ([634a2af](https://github.com/YouTogether/youtogether-frontend/commit/634a2af9207178867309a8daeba4a4a5fb433bf4))
* **video-sync:** [F-V02] Implement leader playback controls ([#107](https://github.com/YouTogether/youtogether-frontend/issues/107)) ([0fbf963](https://github.com/YouTogether/youtogether-frontend/commit/0fbf963f1c38b5fc079465edda38ab779c393168))
* **video-sync:** [F-V03-T1] Add GetCurrentPlaybackStateUseCase ([#102](https://github.com/YouTogether/youtogether-frontend/issues/102)) ([bbe894f](https://github.com/YouTogether/youtogether-frontend/commit/bbe894fbf25b5eb9f67e4786e639febee7132ce2))
* **video-sync:** [F-V03-T2] Wire initial sync, video session metadata fetch, and Firebase disconnect handling ([#108](https://github.com/YouTogether/youtogether-frontend/issues/108)) ([81dd9a4](https://github.com/YouTogether/youtogether-frontend/commit/81dd9a48d98bdcb0bffab03df0308c255dd8cfed))
* **video-sync:** [F-V04] Implement viewer synchronisation and ad-desync recovery ([#109](https://github.com/YouTogether/youtogether-frontend/issues/109)) ([c61e385](https://github.com/YouTogether/youtogether-frontend/commit/c61e385e5a949ecbe24a4a3fda974ce752e0b552))
* **video-sync:** [F-V05-T1] Define presence domain layer ([#103](https://github.com/YouTogether/youtogether-frontend/issues/103)) ([03cd8bc](https://github.com/YouTogether/youtogether-frontend/commit/03cd8bc31e20d6df06c41ea00645562949f23352))
* **video-sync:** [F-V05-T2] Implement Firebase presence data source ([#105](https://github.com/YouTogether/youtogether-frontend/issues/105)) ([2bbe10a](https://github.com/YouTogether/youtogether-frontend/commit/2bbe10aa45227102c8aa2fd3a227df997a86a271))
* **video-sync:** [F-V05-T3] Display the live participant count ([#110](https://github.com/YouTogether/youtogether-frontend/issues/110)) ([c0d8f27](https://github.com/YouTogether/youtogether-frontend/commit/c0d8f279ce6f00d41a9671a06233d69b8c6a8990))
* **video-sync:** [F-V06-T1] Add YoutubeVideoId and CreateVideoSessionUseCase ([#113](https://github.com/YouTogether/youtogether-frontend/issues/113)) ([3b9cc50](https://github.com/YouTogether/youtogether-frontend/commit/3b9cc50e5330005cadbd515d4bc674e17885a85c))
* **video-sync:** [F-V06-T2] Implement video session creation over REST ([#114](https://github.com/YouTogether/youtogether-frontend/issues/114)) ([6226f1d](https://github.com/YouTogether/youtogether-frontend/commit/6226f1d90fc410087f96f3dc3fd346d9c5674690))
* **video-sync:** [F-V06-T3] Let the room leader add a video ([#115](https://github.com/YouTogether/youtogether-frontend/issues/115)) ([73982e2](https://github.com/YouTogether/youtogether-frontend/commit/73982e2f0609a6e02bcd284de0ab37265035dd31))
* **video-sync:** [F-V08-T1] Republish the leader position periodically ([#122](https://github.com/YouTogether/youtogether-frontend/issues/122)) ([7aceed3](https://github.com/YouTogether/youtogether-frontend/commit/7aceed3cc444640bfc50f6d5cb93506fbfeac9e2))


### Bug Fixes

* **video-sync:** [F-V06-T4] Derive isLeader from room ownership ([#111](https://github.com/YouTogether/youtogether-frontend/issues/111)) ([f411d06](https://github.com/YouTogether/youtogether-frontend/commit/f411d060626016d250b9e39d322dde4935e75f30))
* **video-sync:** [F-V06-T4] Firebase database rules and app_fr.arb ([#112](https://github.com/YouTogether/youtogether-frontend/issues/112)) ([f76b616](https://github.com/YouTogether/youtogether-frontend/commit/f76b616a6b7445fd76ae6a12975d1836c9341351))
* **video-sync:** [F-V07-T1] Seed last known session and extrapolate the join position ([#119](https://github.com/YouTogether/youtogether-frontend/issues/119)) ([e2166c8](https://github.com/YouTogether/youtogether-frontend/commit/e2166c85496801e69db0a30fb433b7034f89e98f))
* **video-sync:** [F-V07-T2] Apply the expected position on state transitions ([#120](https://github.com/YouTogether/youtogether-frontend/issues/120)) ([85102b4](https://github.com/YouTogether/youtogether-frontend/commit/85102b45f0e0df5e2e7be8bffb1b4f7734186442))
* **video-sync:** [F-V07-T3] Harden the reconciliation sampling loop ([#121](https://github.com/YouTogether/youtogether-frontend/issues/121)) ([bcbc2c9](https://github.com/YouTogether/youtogether-frontend/commit/bcbc2c9e98770808da3dfb137d4a5f0384d28d03))
* **video-sync:** [F-V09-T1] Neutralise the native player control surface ([#123](https://github.com/YouTogether/youtogether-frontend/issues/123)) ([eeacbf6](https://github.com/YouTogether/youtogether-frontend/commit/eeacbf64d043b0d92b709bcf0c6f5da74e88a67b))

## [0.18.0](https://github.com/YouTogether/youtogether-frontend/compare/v0.17.0...v0.18.0) (2026-07-22)


### Features

* **room:** [F-R01-T1] room domain listing ([#68](https://github.com/YouTogether/youtogether-frontend/issues/68)) ([0e6f525](https://github.com/YouTogether/youtogether-frontend/commit/0e6f5252a2882272e4ce96c71afe1a9d0a49b5bc))
* **room:** [F-R01-T2] room data listing ([#80](https://github.com/YouTogether/youtogether-frontend/issues/80)) ([a01c02c](https://github.com/YouTogether/youtogether-frontend/commit/a01c02cb0615015314f5b205823e0e05e34f705d))
* **room:** [F-R01-T3] implement RoomBloc and room listing UI on HomePage ([#84](https://github.com/YouTogether/youtogether-frontend/issues/84)) ([0a7e223](https://github.com/YouTogether/youtogether-frontend/commit/0a7e223b8a7946cec2598bf19410bbe68b460273))
* **room:** [F-R02-T1] addroom usecase ([#70](https://github.com/YouTogether/youtogether-frontend/issues/70)) ([a712255](https://github.com/YouTogether/youtogether-frontend/commit/a7122558feb5d522950f66117b02e70c80363977))
* **room:** [F-R02-T2] create room data ([#82](https://github.com/YouTogether/youtogether-frontend/issues/82)) ([87a124e](https://github.com/YouTogether/youtogether-frontend/commit/87a124e1dc7ecfc544cdefb94eb330f8f1c76dd4))
* **room:** [F-R02-T3] build room creation form and wire to RoomBloc ([#86](https://github.com/YouTogether/youtogether-frontend/issues/86)) ([672272e](https://github.com/YouTogether/youtogether-frontend/commit/672272e013bebd6897b13bf9904992648a43f941))
* **room:** [F-R03-T1] update room usecase ([#72](https://github.com/YouTogether/youtogether-frontend/issues/72)) ([abe2259](https://github.com/YouTogether/youtogether-frontend/commit/abe22598415ece7b1f560c4e353a279be608d0d0))
* **room:** [F-R03-T2] implement updateRoom in repository and data sources ([#88](https://github.com/YouTogether/youtogether-frontend/issues/88)) ([38298e2](https://github.com/YouTogether/youtogether-frontend/commit/38298e2a0218c3ae6796a1b2cdfd2a7784a84e06))
* **room:** [F-R03-T3] presentation -- build room edit UI with owner-only access ([#92](https://github.com/YouTogether/youtogether-frontend/issues/92)) ([e601c94](https://github.com/YouTogether/youtogether-frontend/commit/e601c94e2b9440e3f11ec939e107b7e2bc26b7fc))
* **room:** [F-R04-T1] delete room usecase ([#74](https://github.com/YouTogether/youtogether-frontend/issues/74)) ([bed9ff8](https://github.com/YouTogether/youtogether-frontend/commit/bed9ff8e56b656eda0e916038b71040f44ad835a))
* **room:** [F-R04-T2] data -- implement deleteRoom in repository and data sources ([#94](https://github.com/YouTogether/youtogether-frontend/issues/94)) ([6c5e687](https://github.com/YouTogether/youtogether-frontend/commit/6c5e687a7840522d8d552774daa3a8de8e79fc61))
* **room:** [F-R04-T3] presentation -- build deletion confirmation and wire navigation ([#93](https://github.com/YouTogether/youtogether-frontend/issues/93)) ([7d0ef2f](https://github.com/YouTogether/youtogether-frontend/commit/7d0ef2fb8a395f304b8460b1b5d5d3250ff790ad))
* **room:** [F-R05-T1] join room usecase ([#76](https://github.com/YouTogether/youtogether-frontend/issues/76)) ([023c631](https://github.com/YouTogether/youtogether-frontend/commit/023c631997e7f5f3b38b65434ee0b38e31c9edba))
* **room:** [F-R05-T2] data -- implement joinRoom in repository and data sources ([#95](https://github.com/YouTogether/youtogether-frontend/issues/95)) ([6ee6d01](https://github.com/YouTogether/youtogether-frontend/commit/6ee6d01743c1c3320cc7ef6981c01124c9f99e29))
* **room:** [F-R05-T3] presentation -- wire join button and navigation ([#97](https://github.com/YouTogether/youtogether-frontend/issues/97)) ([55bf011](https://github.com/YouTogether/youtogether-frontend/commit/55bf011b33b04415eb4f618d460380576276222a))
* **room:** [F-R06-T1] leave room usecase ([#78](https://github.com/YouTogether/youtogether-frontend/issues/78)) ([8f098e3](https://github.com/YouTogether/youtogether-frontend/commit/8f098e353d3be609190dcf2cd7e5446f7dab024a))
* **room:** [F-R06-T2] data -- implement leaveRoom in repository and data sources ([#96](https://github.com/YouTogether/youtogether-frontend/issues/96)) ([f8fc62e](https://github.com/YouTogether/youtogether-frontend/commit/f8fc62e42b0d49ec8aca0e872aa2032583c02ed5))
* **room:** [F-R06-T3] presentation -- wire leave button with owner guard ([#98](https://github.com/YouTogether/youtogether-frontend/issues/98)) ([756d11e](https://github.com/YouTogether/youtogether-frontend/commit/756d11e6684c3e5d95fe12fba909c95cb1717b15))
* **room:** room detail page ([#91](https://github.com/YouTogether/youtogether-frontend/issues/91)) ([907137c](https://github.com/YouTogether/youtogether-frontend/commit/907137c4f9e4bc0ed1b26785e1706b48425f0d0c))
* **room:** room detail prereq get room by domain ([#89](https://github.com/YouTogether/youtogether-frontend/issues/89)) ([6c171dd](https://github.com/YouTogether/youtogether-frontend/commit/6c171dd4c8a676a4798c1a18a9a57c1033537889))
* **room:** room detail prereq get room by id data ([#90](https://github.com/YouTogether/youtogether-frontend/issues/90)) ([3692b25](https://github.com/YouTogether/youtogether-frontend/commit/3692b25363309745558ef1834c4feff1bab5556d))


### Bug Fixes

* **auth:** post login state sync and home navigation ([#87](https://github.com/YouTogether/youtogether-frontend/issues/87)) ([c736dd7](https://github.com/YouTogether/youtogether-frontend/commit/c736dd74733dae79e2f357021c1990af57b3e464))

## [0.17.0](https://github.com/YouTogether/youtogether-frontend/compare/v0.16.0...v0.17.0) (2026-07-20)


### Features

* **infra:** [F-INF-T1] profile route ([#66](https://github.com/YouTogether/youtogether-frontend/issues/66)) ([49eee86](https://github.com/YouTogether/youtogether-frontend/commit/49eee862b9c3b5adeffea339a04e0833d19728fc))

## [0.16.0](https://github.com/YouTogether/youtogether-frontend/compare/v0.15.0...v0.16.0) (2026-07-20)


### Features

* **infra:** [F-INF-T1] application shell ([#64](https://github.com/YouTogether/youtogether-frontend/issues/64)) ([c49d5cf](https://github.com/YouTogether/youtogether-frontend/commit/c49d5cf1137b5632ddf19822e99e51808e618a8d))

## [0.15.0](https://github.com/YouTogether/youtogether-frontend/compare/v0.14.0...v0.15.0) (2026-07-13)


### Features

* **auth:** [F-A05-T1] ProfilePage widget ([#62](https://github.com/YouTogether/youtogether-frontend/issues/62)) ([0cf0b7d](https://github.com/YouTogether/youtogether-frontend/commit/0cf0b7dbe94d308091bed8f99e4caacc09589791))

## [0.14.0](https://github.com/YouTogether/youtogether-frontend/compare/v0.13.0...v0.14.0) (2026-07-13)


### Features

* **auth:** [F-A04-T3] wire AuthBloc.logoutRequested ([#60](https://github.com/YouTogether/youtogether-frontend/issues/60)) ([d890ed0](https://github.com/YouTogether/youtogether-frontend/commit/d890ed0c3caac828e25901587c11fda1e57ee5f3))

## [0.13.0](https://github.com/YouTogether/youtogether-frontend/compare/v0.12.0...v0.13.0) (2026-07-13)


### Features

* **auth:** [F-A04-T2] logout data layer ([#58](https://github.com/YouTogether/youtogether-frontend/issues/58)) ([898df0f](https://github.com/YouTogether/youtogether-frontend/commit/898df0f586c53ad2249666e19ab3312d78582c23))

## [0.12.0](https://github.com/YouTogether/youtogether-frontend/compare/v0.11.0...v0.12.0) (2026-07-13)


### Features

* **auth:** [F-A03-T3] AuthBloc for global session state ([#56](https://github.com/YouTogether/youtogether-frontend/issues/56)) ([8dae282](https://github.com/YouTogether/youtogether-frontend/commit/8dae28271fc7e0c9b8d35de6873f6470d6504425))

## [0.11.0](https://github.com/YouTogether/youtogether-frontend/compare/v0.10.0...v0.11.0) (2026-07-12)


### Features

* **auth:** [F-A03-T2] token lifecycle ([#54](https://github.com/YouTogether/youtogether-frontend/issues/54)) ([de709c8](https://github.com/YouTogether/youtogether-frontend/commit/de709c880bbf01d4d7293285a8b10ab74b6250e4))

## [0.10.0](https://github.com/YouTogether/youtogether-frontend/compare/v0.9.0...v0.10.0) (2026-07-12)


### Features

* **auth:** [F-A02-T3] login cubit page ([#52](https://github.com/YouTogether/youtogether-frontend/issues/52)) ([fcffec6](https://github.com/YouTogether/youtogether-frontend/commit/fcffec6bf4dbac19638dba4e9b48c2b0594c0a13))

## [0.9.0](https://github.com/YouTogether/youtogether-frontend/compare/v0.8.0...v0.9.0) (2026-07-07)


### Features

* **auth:** [F-A02-T2] login data layer ([#50](https://github.com/YouTogether/youtogether-frontend/issues/50)) ([f64ad2a](https://github.com/YouTogether/youtogether-frontend/commit/f64ad2a1257dacc97dfa15453bb6f1e1d39fa88c))

## [0.8.0](https://github.com/YouTogether/youtogether-frontend/compare/v0.7.0...v0.8.0) (2026-07-07)


### Features

* **auth:** [F-A01-T5] register page ([#48](https://github.com/YouTogether/youtogether-frontend/issues/48)) ([8b4ad40](https://github.com/YouTogether/youtogether-frontend/commit/8b4ad402440d9497ecdaf945a8e53535c7c82a8b))

## [0.7.0](https://github.com/YouTogether/youtogether-frontend/compare/v0.6.0...v0.7.0) (2026-07-07)


### Features

* **auth:** [F-A01-T4] register cubit ([#46](https://github.com/YouTogether/youtogether-frontend/issues/46)) ([86f751a](https://github.com/YouTogether/youtogether-frontend/commit/86f751a929d2fb6ee38ba4116dba620e033f60dc))

## [0.6.0](https://github.com/YouTogether/youtogether-frontend/compare/v0.5.0...v0.6.0) (2026-07-06)


### Features

* **auth:** [F-A01-T3] register remote datasource ([#44](https://github.com/YouTogether/youtogether-frontend/issues/44)) ([3511d13](https://github.com/YouTogether/youtogether-frontend/commit/3511d13606cbc08fcf453852c1b1301fdeda2878))

## [0.5.0](https://github.com/YouTogether/youtogether-frontend/compare/v0.4.0...v0.5.0) (2026-07-06)


### Features

* **auth:** F-A01-T2 register repository impl ([#42](https://github.com/YouTogether/youtogether-frontend/issues/42)) ([e249f8d](https://github.com/YouTogether/youtogether-frontend/commit/e249f8dbb8411c7fca989aaf1968dce02f2da46f))

## [0.4.0](https://github.com/YouTogether/youtogether-frontend/compare/v0.3.0...v0.4.0) (2026-07-06)


### Features

* **auth:** [F-A04-T1] logout usecase contract ([#40](https://github.com/YouTogether/youtogether-frontend/issues/40)) ([dd07223](https://github.com/YouTogether/youtogether-frontend/commit/dd07223447bb6d5799e512d55acd0fb0a9d5820b))

## [0.3.0](https://github.com/YouTogether/youtogether-frontend/compare/v0.2.0...v0.3.0) (2026-07-06)


### Features

* **auth:** [F-A03-T1] session restoration usecases ([#38](https://github.com/YouTogether/youtogether-frontend/issues/38)) ([ebe5672](https://github.com/YouTogether/youtogether-frontend/commit/ebe5672ffe85f0600497552f858512a92b1fa467))

## [0.2.0](https://github.com/YouTogether/youtogether-frontend/compare/v0.1.0...v0.2.0) (2026-07-06)


### Features

* **auth:** [F-A02-T1] login usecase contract ([#36](https://github.com/YouTogether/youtogether-frontend/issues/36)) ([0b7b4fc](https://github.com/YouTogether/youtogether-frontend/commit/0b7b4fcc8192ded5ac3199f3d08e2c818c6eace1))

## 1.0.0 (2026-07-06)


### Features

* **auth:** [F-A01-T1] register usecase contract ([#32](https://github.com/YouTogether/youtogether-frontend/issues/32)) ([6393877](https://github.com/YouTogether/youtogether-frontend/commit/6393877e04789eab4b31bd91601e7408cd31c9b0))
* **infra:** Add git hooks configuration ([#28](https://github.com/YouTogether/youtogether-frontend/issues/28)) ([2e19635](https://github.com/YouTogether/youtogether-frontend/commit/2e19635ab0cf5fda812a3fa7dd1d9c9b56bd2038))
* **infra:** CI and release please workflows setup ([#27](https://github.com/YouTogether/youtogether-frontend/issues/27)) ([f8783e1](https://github.com/YouTogether/youtogether-frontend/commit/f8783e1942a987a8266e2f1a920abdf30cf5bc61))
* **management:** Create pull_request_template.md ([#26](https://github.com/YouTogether/youtogether-frontend/issues/26)) ([b3956c7](https://github.com/YouTogether/youtogether-frontend/commit/b3956c70f651611ae262310838464a33dca8fc39))
* **management:** Update pull_request_template.md ([9b1e500](https://github.com/YouTogether/youtogether-frontend/commit/9b1e500579f7c7933054d974a7ff48075115a495))
* **project:** create epic issue template ([51c790b](https://github.com/YouTogether/youtogether-frontend/commit/51c790baf441cb29540b9117e865dbf1a0e9d467))
* **project:** Create task issue template ([67bd53a](https://github.com/YouTogether/youtogether-frontend/commit/67bd53a6ad626099cb1353c827bb40a988123efe))


### Bug Fixes

* **infra:** extract git hooks scripts to avoid yaml quoting issues ([#29](https://github.com/YouTogether/youtogether-frontend/issues/29)) ([7a99070](https://github.com/YouTogether/youtogether-frontend/commit/7a99070c6c20f9f519d54ed97dc4522eac309123))
