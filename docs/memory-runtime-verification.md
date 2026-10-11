# Memory runtime verification - 2026-10-11

Historical isolated gameplay observations from PRs #3021, #3022 and #3023, preserved on [PR #3026](https://github.com/Civ13/Civ13/pull/3026). BYOND 516.1681 on Windows; Nomads Temperate, maps/nomads/nomads.dmm, 155 x 225 x 2. This is historical verification, not a new test run or proof of production OOM remediation.

Generated logs, queries, manifests, screenshots, sampled frames and videos were removed from the current tree. Original bundles remain in published Git history at 3707870d9; history was not rewritten. Media was uploaded to PR comments and independently downloaded without authentication: all 32 assets returned HTTP 200 with SHA-256 matching the originals. Videos encode genuine sampled frames at 2 fps and are not timing benchmarks.

## observer

Tested commit: `104f669840b61a972dbd17b66f79ad3e2a751834`.

### Replication

- Check out commit 104f669840b61a972dbd17b66f79ad3e2a751834
- Run tests/memory/start-gameplay-evidence.ps1 -ByondBin <516.1681 bin> -Scenario observer -Port 16994
- Connect Dream Seeker 516.1681 to byond://127.0.0.1:16994
- Run query-gameplay-evidence.ps1 with SessionJson and ByondBin for prepare, wait for state 3, then join, run, examine
- Close the native Notes popup; capture PASS, press Right/Down with keyboard, capture sampled frames
- Stop only the task-owned server/client PIDs; preserve closed logs

### Historical results and limits

- **passed**: Full game plus opt-in adapter compiles. 0 errors, 0 warnings.
- **passed**: 100 observer cycles deliver callbacks and release probe references. PASS in game. Probe uses real GLOB observation objects.
- **passed**: Nomad spawn, keyboard movement and tree Examine after check. Actual client and map; observer position changed from x1 to x4. Water adapter step returned zero despite changed coordinates; keyboard movement is separately visible.

### Preserved media

- [observer-frame-00.jpg](https://github.com/user-attachments/assets/8befd982-3916-4f12-b64b-5831f010f695) - SHA-256 `3df47b26de59eed9811b784fa401a8e19e5d72d9985d308e4f1e1d46315ae87f`.
- [observer-frame-01.jpg](https://github.com/user-attachments/assets/4e0395e0-6b25-4716-a68b-c76f6e06a0a3) - SHA-256 `713c80476a23d7a90f243d2aa7801d70d188cc34eb63e11e0dfc234560974250`.
- [observer-frame-02.jpg](https://github.com/user-attachments/assets/492f838f-b12e-48d1-8980-f0955845aeb7) - SHA-256 `4631007753cae6abde574b9b1fa856d94ea081e15dae66ea5dc7eeacd81ff020`.
- [observer-frame-03.jpg](https://github.com/user-attachments/assets/b46883ae-7a0c-46d5-9584-a438c12c3955) - SHA-256 `440e87fab9d6eb92576010fb0b8475252ffde01056f2ba877605f67dfef389ae`.
- [observer-frame-04.jpg](https://github.com/user-attachments/assets/a036a4b5-432c-42bc-9198-64cc323a5194) - SHA-256 `cb118fc088c2f98fbed42fb57d8ac914e952c4860f416643fdd69bbabbd74f29`.
- [observer-frame-05.jpg](https://github.com/user-attachments/assets/a16242d9-4420-46a3-bed3-9e9486ed347e) - SHA-256 `c8a38ef9bf50b3fa5d343577364a10d03feff246f19eaf33b6f1a7afa793c6dd`.
- [observer-movement-examine.jpg](https://github.com/user-attachments/assets/ee2b2694-adb9-4c75-be92-1b4073b2a42e) - SHA-256 `c8a38ef9bf50b3fa5d343577364a10d03feff246f19eaf33b6f1a7afa793c6dd`.
- [observer-pass.jpg](https://github.com/user-attachments/assets/cb28e125-4809-4213-80b4-6bbb95918f19) - SHA-256 `44cd6b6f1697478a9c829169fae20f9d87e31cb8a432c9a9fbc0afeccb4c5820`.
- [observer-sampled-movement.mp4](https://github.com/user-attachments/assets/50825066-52a8-4284-90e9-3ebb7c945e64) - SHA-256 `e575f0fbf9ac7f43ddc0717a00ac408ca43f1d7f44afbae339014c310297ce36`.

## season

Tested commit: `a7e2ce748b07a178a2b79059829b89bd038fa457`.

### Replication

- Check out a7e2ce748b07a178a2b79059829b89bd038fa457
- Run tests/memory/start-gameplay-evidence.ps1 -ByondBin <516.1681-bin> -Scenario season -Port 16996; connect a local admin Dream Seeker
- Run query-gameplay-evidence.ps1 with generated SessionJson and ByondBin for prepare, wait for playing, then join
- Close Notes popup; capture Spring, then action run four times to reach Summer, Fall, Winter, Spring; capture each transition
- In Winter use Right/Down keyboard inputs and capture sampled frames. Wait at least 300 seconds after Spring for delayed temperate thaw; examine a nearby tree
- Stop exact task-owned server/client PIDs; preserve closed logs

### Historical results and limits

- **passed**: Full-game plus optional test adapter compiles. 0 errors, 0 warnings; production DME unchanged.
- **passed**: Spring through Summer/Fall/Winter back to Spring with delayed thaw. One forced local cycle; final capture after 300-second thaw shows grass restored.
- **passed**: Nomad spawn, limited Winter movement and tree Examine in Spring. Actor moved x1 to x2 during Winter. Unclothed actor suffered cold injuries; later keyboard movement did not change position. Tree Examine returned normally. No admin healing was used.
- **not-run**: Repeated completed full-game season cycles. This graphical run exercised one cycle. Separate accelerated production-body fixture passed 20 cycles.
- **not-run**: Repeated full-game baseline/peak/settled memory samples. No phased full-game memory sampling was performed; short gameplay captures do not prove OOM remediation.

### Preserved media

- [season-fall.jpg](https://github.com/user-attachments/assets/acd4d200-3322-4505-beeb-dde5efe10c95) - SHA-256 `a00f6cfdefebcd9f3f50615ff1ffe56751193e81bbf3f889399afe3edcf95552`.
- [season-frame-00.jpg](https://github.com/user-attachments/assets/90a532b1-1d0b-46ad-ba19-e29858490d1f) - SHA-256 `2690b7fc27629f9574fd54d7219038ec1359ebc7b50eecf4f1330a8d237afa41`.
- [season-frame-01.jpg](https://github.com/user-attachments/assets/f31ebc42-28a3-4917-8160-b99f5d827494) - SHA-256 `0aa0450bbf899d4c374154cd1af7ed14cab8f10d8536f234e9bf80751140d565`.
- [season-frame-02.jpg](https://github.com/user-attachments/assets/4970d1a6-3e93-4c2f-82ed-fbdd4bef5555) - SHA-256 `ea1f8f718a858abffa2a6695bff99c360e57a8843f6781ef585dc8296caf38b8`.
- [season-frame-03.jpg](https://github.com/user-attachments/assets/9604adcc-d3a2-4bf9-8d7c-2ca543dc6159) - SHA-256 `63b7bb324807af11ec8a569bb39f7b17ef66efe2958551545994f727b9153775`.
- [season-frame-04.jpg](https://github.com/user-attachments/assets/a4448244-6198-4313-a7ce-2b05c8cb9558) - SHA-256 `44651b98e0840806cf9935f2e60814c202cc5c39296e6f75d7b4943a41501533`.
- [season-frame-05.jpg](https://github.com/user-attachments/assets/14572839-8614-4f5a-ae7b-7dc4f7ae0c60) - SHA-256 `1ee43f18ade8164a90be5d76cda0e996191a9b19408059885b38ed2b8a980354`.
- [season-sampled-movement.mp4](https://github.com/user-attachments/assets/ec4191fd-d85d-44f4-9ec9-cfe1c8ab270f) - SHA-256 `d2fab74ed8f0202f1872a63898fb5b844eb82f7f0915596220d58d3eb196f7ec`.
- [season-spring-return.jpg](https://github.com/user-attachments/assets/0da1184d-a90b-4027-835b-852e0a7494a5) - SHA-256 `c88d1540b9767db16faa5318b09e1d43396c5ec3775a43c997209d7446282741`.
- [season-spring-thaw.jpg](https://github.com/user-attachments/assets/cb96d44f-0b83-459f-a015-6c2db3341d75) - SHA-256 `62ee58eb0affb2b574655386bbc404d4450116360868eda9da71fdd032a36099`.
- [season-spring.jpg](https://github.com/user-attachments/assets/df0c71da-54ab-4a2e-8d46-deea36ecf6fc) - SHA-256 `c4af57357124e093f373bbcca2f78ef0269438efa306fb7a9744fb5c02c04689`.
- [season-summer.jpg](https://github.com/user-attachments/assets/80397935-c0c7-4a00-b367-2af01f5dcaf7) - SHA-256 `af0e01e97b9207d782180af18ac9f6f605d74443d105d1805dfea2faa52d972e`.
- [season-winter.jpg](https://github.com/user-attachments/assets/2179d497-d2bc-4f5c-8710-0cdebcd506e1) - SHA-256 `3955172a267e59a56d03e8670c247f557d423f8932eec932875469389db5ad69`.

## water

Tested commit: `e19c52ad9a155cf62529d5a51430f5c2d797179f`.

### Replication

- Check out commit e19c52ad9a155cf62529d5a51430f5c2d797179f
- Run tests/memory/start-gameplay-evidence.ps1 -ByondBin <516.1681 bin> -Scenario water -Port 16992
- Connect Dream Seeker 516.1681 to byond://127.0.0.1:16992
- Run query-gameplay-evidence.ps1 with SessionJson and ByondBin for prepare, wait for state 3, then join, run, examine
- Close the native Notes popup; capture PASS, press Right/Down with keyboard, capture sampled frames
- Stop only the task-owned server/client PIDs; preserve closed logs

### Historical results and limits

- **passed**: Full game plus opt-in adapter compiles. 0 errors, 0 warnings.
- **passed**: 20 water/deep/dry cycles maintain registry baseline. Baseline 6835; final 6836 includes one deliberately retained visible tile.
- **passed**: Nomad spawn, keyboard movement and tree Examine after check. Actual client and map; observer position changed from x1 to x4. Water adapter step returned zero despite changed coordinates; keyboard movement is separately visible.

### Preserved media

- [water-examine.jpg](https://github.com/user-attachments/assets/68a5d9b3-68ad-4c66-8929-fb364674fb17) - SHA-256 `9802707cad9504874d16bf6189f5856f88cb3a98e4e760ae70c987df851fee42`.
- [water-frame-00.jpg](https://github.com/user-attachments/assets/f2c7f0a2-ab37-4732-b441-314a0c44f48a) - SHA-256 `ef81544ddb832edb807f8d68f93f53c2255307cf6c08ef4ac08ced16aa82a284`.
- [water-frame-01.jpg](https://github.com/user-attachments/assets/8ad90fa1-6265-493e-a02d-1acfd0fe9547) - SHA-256 `8b415c4dbcdf984cc292212722586dfe4478ea5e95720b1348accd6921d6ca55`.
- [water-frame-02.jpg](https://github.com/user-attachments/assets/1c7ef691-3667-4f30-bcb2-edc6f6982d52) - SHA-256 `2e041aade690f5abc068db70300bf5f1f05ea1be0249e2b65c54fad869d703f3`.
- [water-frame-03.jpg](https://github.com/user-attachments/assets/2086de46-9cad-40aa-83e6-b658f8366007) - SHA-256 `e875d8f7afdd2fcf3c03a9037eaef6b08db981fe3846c3541bf0baf932968e0a`.
- [water-frame-04.jpg](https://github.com/user-attachments/assets/d188ce80-11be-4b3d-82b1-ac1ae79cb0cf) - SHA-256 `d1b04d23c5d454e2833455a093a565aa0a5aa0c28e3084c86da89b1ec9a26b90`.
- [water-frame-05.jpg](https://github.com/user-attachments/assets/01eb621c-75b3-42d7-a46f-801ace165e48) - SHA-256 `8fa401871609dad51ca81afd8a79ef5f87fe3f1664ad8b47c2ccffafd0c27aa4`.
- [water-movement.jpg](https://github.com/user-attachments/assets/6e025d5b-4306-48eb-8498-a88dbe5532ca) - SHA-256 `309be4437ff027398c3b255ba895765013d8611c7ddd587ced05cc7122ba48e0`.
- [water-pass.jpg](https://github.com/user-attachments/assets/292b6409-8450-43db-a6d3-00d75ab91645) - SHA-256 `ce62337ab4c0d8dfab58adf7ad6aca680c7a11d891c8fcd52f0ae60c11c6edf1`.
- [water-sampled-movement.mp4](https://github.com/user-attachments/assets/7f43b22d-c2cd-4212-9eec-009c3eaa54cd) - SHA-256 `f6b8343be728568813ff6d6c5ffb8ecf151eb0a334980ad1cd333a06cda87765`.

Keep reusable fixtures and validation scripts in version control. Store generated runtime bundles outside the checkout and attach useful images/videos to the relevant PR; verify access before deleting local copies.
