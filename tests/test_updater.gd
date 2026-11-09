extends SceneTree

func _initialize() -> void:
    assert(ReleaseUpdater.is_newer("v0.2.0", "0.1.9"))
    assert(ReleaseUpdater.is_newer("1.0.0", "0.99.99"))
    assert(ReleaseUpdater.is_newer("0.10.0", "0.9.9"))
    assert(not ReleaseUpdater.is_newer("v1.2.3", "1.2.3"))
    assert(not ReleaseUpdater.is_newer("0.9.0", "0.10.0"))
    for invalid in ["v1.2", "1.2.3-beta", "1.2.x", "-1.2.3", "1.2.3.4", ""]:
        assert(not ReleaseUpdater.is_newer(invalid, "0.0.0"))
    var release := ReleaseUpdater.parse_release(FileAccess.get_file_as_string("res://tests/release_latest.json"))
    assert(release.tag_name == "v0.2.0" and release.body == "Neue Module und Fehlerbehebungen.")
    assert(ReleaseUpdater.asset_url(release, "Android").ends_with("Scrapforge-android.apk"))
    assert(ReleaseUpdater.asset_url(release, "Windows") == release.html_url)
    assert(ReleaseUpdater.asset_url(release, "Linux") == release.html_url)
    assert(ReleaseUpdater.asset_url({"assets":[]}, "Android") == "")
    assert(ReleaseUpdater.parse_release("not json").is_empty())
    assert(ReleaseUpdater.parse_release('{"tag_name":"v2.0.0","html_url":"https://example.com"}').is_empty())
    print("Update-Tests bestanden")
    quit()
