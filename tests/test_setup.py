"""Regression checks use temporary homes and fake installers; no privileged writes."""
import copy
import importlib.util
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("setup_config", ROOT / "scripts/setup-config.py")
CONFIG = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(CONFIG)


class ConfigTests(unittest.TestCase):
    def test_php_fresh_and_repeated_configuration(self):
        with tempfile.TemporaryDirectory() as name:
            directory = Path(name)
            (directory / "conf.d").mkdir()
            ini = directory / "php.ini"
            ini.write_text("memory_limit=256M\n;extension=curl\nextension=\"/usr/lib/php/modules/intl.so\"\n")
            (directory / "conf.d/xdebug.ini").write_text("zend_extension=xdebug.so\n")
            original = ini.read_bytes()
            rendered = CONFIG.render_php(directory, "[PHP Modules]\niconv\n")
            self.assertIn("extension=curl\n", rendered)
            self.assertIn("extension=pdo_sqlite\n", rendered)
            self.assertNotIn("extension=intl\n", rendered)
            self.assertNotIn("extension=iconv\n", rendered)
            self.assertNotIn("zend_extension=", rendered)
            self.assertIn("xdebug.mode=debug", rendered)
            (directory / "conf.d" / CONFIG.PHP_CONFIG).write_text(rendered)
            self.assertEqual(rendered, CONFIG.render_php(directory, "[PHP Modules]\niconv\n"))
            self.assertEqual(original, ini.read_bytes())

    @unittest.skipUnless(shutil.which("php"), "PHP unavailable for runtime validation")
    def test_php_loads_real_extensions_without_duplicate_warnings(self):
        with tempfile.TemporaryDirectory() as name:
            directory = Path(name)
            (directory / "conf.d").mkdir()
            (directory / "php.ini").write_text("memory_limit=256M\n")
            builtins = subprocess.check_output(["php", "-n", "-m"], text=True)
            (directory / "conf.d" / CONFIG.PHP_CONFIG).write_text(CONFIG.render_php(directory, builtins))
            code = 'echo json_encode([get_loaded_extensions(), ini_get("xdebug.mode"), ini_get("memory_limit")]);'
            result = subprocess.run(["php", "-c", str(directory / "php.ini"), "-r", code],
                                    env={**os.environ, "PHP_INI_SCAN_DIR": str(directory / "conf.d")},
                                    capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(result.stderr, "")
            modules, mode, limit = json.loads(result.stdout)
            self.assertTrue(set(CONFIG.PHP_EXTENSIONS).issubset({m.lower() for m in modules}))
            self.assertIn("xdebug", modules)
            self.assertEqual(mode, "debug")
            self.assertEqual(limit, "256M")

    def test_shell_preserves_unrelated_config_and_clock_options(self):
        config = json.loads((ROOT / "baseline/shell.json.bak").read_text())
        config["bar"]["position"] = "bottom"
        config["plugins"] = [{"id": "unrelated.plugin", "setting": True}]
        config["custom"] = {"preserve": [1, 2, 3]}
        before = copy.deepcopy(config)
        result = CONFIG.configure_shell(config)
        self.assertEqual(result["bar"]["position"], "bottom")
        self.assertEqual(result["plugins"], before["plugins"])
        self.assertEqual(result["idle"], before["idle"])
        self.assertEqual(result["custom"], before["custom"])
        old_clock = next(x for x in before["bar"]["layout"]["center"] if x["id"] == "omarchy.clock")
        new_clock = next(x for x in result["bar"]["layout"]["center"] if x["id"] == "instrument-cluster")
        self.assertEqual(new_clock, {**old_clock, "id": "instrument-cluster"})
        self.assertEqual(result["bar"]["centerAnchor"], "instrument-cluster")
        self.assertEqual(result["bar"]["layout"]["left"], before["bar"]["layout"]["left"])
        self.assertEqual(result["bar"]["layout"]["right"], before["bar"]["layout"]["right"] + [{"id": "omaconnect"}])
        self.assertEqual(CONFIG.configure_shell(copy.deepcopy(result)), result)

    def test_existing_plugins_keep_their_placement_and_settings(self):
        config = {"bar": {"layout": {
            "left": [{"id": "omaconnect", "showBarBattery": True}],
            "center": [{"id": "instrument-cluster", "format": "HH:mm"}, {"id": "omarchy.clock"}],
            "right": [{"id": "unrelated"}]}}}
        result = CONFIG.configure_shell(config)
        self.assertEqual(result["bar"]["layout"]["left"], [{"id": "omaconnect", "showBarBattery": True}])
        self.assertEqual(result["bar"]["layout"]["center"], [{"id": "instrument-cluster", "format": "HH:mm"}])
        self.assertEqual(result["bar"]["layout"]["right"], [{"id": "unrelated"}])

    def test_shell_backup_only_when_changed_and_invalid_json_is_preserved(self):
        with tempfile.TemporaryDirectory() as name:
            path = Path(name) / "shell.json"
            fallback = ROOT / "baseline/shell.json.bak"
            path.write_text(fallback.read_text())
            original = path.read_bytes()
            CONFIG.write_shell(path, fallback)
            self.assertEqual(len(list(path.parent.glob("*.bak.*"))), 1)
            backup = next(path.parent.glob("*.bak.*"))
            self.assertEqual(backup.read_bytes(), original)
            changed = path.read_bytes()
            CONFIG.write_shell(path, fallback)
            self.assertEqual(path.read_bytes(), changed)
            self.assertEqual(len(list(path.parent.glob("*.bak.*"))), 1)
            path.write_text("invalid json")
            with self.assertRaises(json.JSONDecodeError):
                CONFIG.write_shell(path, fallback)
            self.assertEqual(path.read_text(), "invalid json")


class ScriptTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.home = Path(self.temporary.name)
        self.bin = self.home / "bin"
        self.bin.mkdir()
        self.calls = self.home / "calls"
        self.env = {**os.environ, "HOME": str(self.home), "XDG_STATE_HOME": str(self.home / "state"),
                    "PATH": str(self.bin) + ":" + os.environ["PATH"], "CALLS": str(self.calls),
                    "DRY_RUN": "0", "PYTHONDONTWRITEBYTECODE": "1"}
        for command in ["sudo", "yay", "omarchy", "omarchy-shell", "mise", "mkcert", "ddev"]:
            self.stub(command, 'printf "%s\\n" "$0 $*" >>"$CALLS"\n')
        self.stub("pacman", 'if [[ "$1" == -Q ]]; then exit 0; fi\nexit 20\n')
        self.stub("xdg-settings", '[[ "$1" != get ]] || echo zen.desktop\n')

    def stub(self, command, script):
        path = self.bin / command
        path.write_text("#!/bin/bash\nset -eu\n" + script)
        path.chmod(0o755)

    def run_script(self, name, dry=False):
        return subprocess.run(["bash", str(ROOT / "scripts" / name), *(["--dry-run"] if dry else [])],
                              env=self.env, capture_output=True, text=True)

    def test_only_approved_packages_are_updated_on_rerun(self):
        result = self.run_script("ensure-apps.sh")
        self.assertEqual(result.returncode, 0, result.stderr)
        calls = self.calls.read_text().splitlines()
        self.assertEqual(len(calls), 2, calls)
        self.assertTrue(calls[0].endswith("pacman -S --needed --noconfirm -- kdeconnect php composer php-sqlite xdebug mkcert"))
        self.assertTrue(calls[1].endswith("yay -S --needed --noconfirm -- ddev-bin orca-ide-bin"))

    def test_dry_runs_do_not_execute_installers_or_write_home(self):
        for name in ["ensure-apps.sh", "ensure-development.sh", "ensure-connectivity.sh", "ensure-plugins.sh"]:
            before = {str(p.relative_to(self.home)): p.read_bytes() for p in self.home.rglob("*") if p.is_file()}
            result = self.run_script(name, dry=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            after = {str(p.relative_to(self.home)): p.read_bytes() for p in self.home.rglob("*") if p.is_file()}
            self.assertEqual(before, after, name)
            self.assertIn("[dry-run]", result.stdout)

    def test_kdeconnect_rules_only(self):
        self.stub("kdeconnect-cli", "exit 0\n")
        self.stub("ufw", "exit 0\n")
        result = self.run_script("ensure-connectivity.sh")
        self.assertEqual(result.returncode, 0, result.stderr)
        calls = self.calls.read_text().splitlines()
        self.assertEqual(len(calls), 2)
        self.assertTrue(calls[0].endswith("ufw allow 1714:1764/tcp comment KDE Connect"))
        self.assertTrue(calls[1].endswith("ufw allow 1714:1764/udp comment KDE Connect"))

    def test_development_commands_do_not_provision_a_project(self):
        self.stub("php", 'if [[ "$1" == -n ]]; then echo Core; fi\n')
        self.stub("composer", '[[ "$*" == --version ]]\n')
        self.stub("docker", '[[ "$*" == "compose version" || "$*" == info ]]\n')
        self.stub("id", 'if [[ "$*" == -un ]]; then echo setupuser; else echo setupuser; fi\n')
        self.stub("sg", 'printf "%s\\n" "sg $*" >>"$CALLS"\n')
        self.stub("mkcert", '[[ "${TRUST_STORES:-}" == system && "$*" == -install ]]\nprintf "mkcert system -install\\n" >>"$CALLS"\n')
        self.stub("ddev", '[[ "$*" == version ]]\nprintf "ddev version\\n" >>"$CALLS"\n')
        result = self.run_script("ensure-development.sh")
        self.assertEqual(result.returncode, 0, result.stderr)
        calls = self.calls.read_text()
        self.assertIn("mise use --global --fuzzy node@latest", calls)
        self.assertIn("systemctl enable --now docker.service", calls)
        self.assertIn("usermod -aG docker setupuser", calls)
        self.assertIn("mkcert system -install", calls)
        self.assertIn("ddev version", calls)
        self.assertNotIn("ddev start", calls)
        self.assertNotIn("ddev config", calls)
        self.assertNotIn("--pin", calls)
        self.assertNotIn(".ddev", {p.name for p in self.home.iterdir()})

    def test_full_installer_dry_run_preserves_existing_launchers(self):
        self.stub("hyprctl", '''cat <<'MODES'
Monitor HDMI-A-1 (ID 0):
    availableModes: 1920x1080@60.00Hz 1920x1080@180.00Hz
MODES
''')
        self.stub("fish", 'exit 1\n')
        launcher = self.home / ".local/share/applications/foot.desktop"
        launcher.parent.mkdir(parents=True)
        launcher.write_text("preserve this launcher")
        before = {str(p.relative_to(self.home)): p.read_bytes() for p in self.home.rglob("*") if p.is_file()}
        result = subprocess.run(["bash", str(ROOT / "install.sh"), "--dry-run"],
                                env=self.env, capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        after = {str(p.relative_to(self.home)): p.read_bytes() for p in self.home.rglob("*") if p.is_file()}
        self.assertEqual(before, after)
        self.assertIn("node@latest", result.stdout)
        self.assertIn("instrument-cluster", result.stdout)
        self.assertIn("ddev-bin", result.stdout)
        self.assertIn("orca-ide-bin", result.stdout)

    def test_plugin_validation_failure_keeps_copied_plugin_and_shell(self):
        target = self.home / ".config/omarchy/plugins/instrument-cluster"
        target.mkdir(parents=True)
        (target / "preserve.txt").write_text("original plugin")
        config = target.parent.parent / "shell.json"
        config.write_text('{"preserve": true}')
        self.stub("git", 'mkdir -p "${@: -1}"\necho "{}" >"${@: -1}/manifest.json"\n')
        self.stub("omarchy", 'exit 1\n')
        result = self.run_script("ensure-plugins.sh")
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual((target / "preserve.txt").read_text(), "original plugin")
        self.assertEqual(config.read_text(), '{"preserve": true}')
        self.assertFalse((self.home / "state").exists())

    def test_copied_plugins_migrate_with_backups_and_preserved_layout(self):
        target = self.home / ".config/omarchy/plugins/instrument-cluster"
        target.mkdir(parents=True)
        (target / "preserve.txt").write_text("original plugin")
        config = target.parent.parent / "shell.json"
        config.write_text((ROOT / "baseline/shell.json.bak").read_text())
        self.stub("git", '''destination="${@: -1}"
mkdir -p "$destination/.git"
if [[ "$*" == *omarchy-instrument-cluster-plugin* ]]; then plugin_id=instrument-cluster; else plugin_id=omaconnect; fi
printf '{"id":"%s"}' "$plugin_id" >"$destination/manifest.json"
''')
        result = self.run_script("ensure-plugins.sh")
        self.assertEqual(result.returncode, 0, result.stderr)
        backups = list((self.home / "state/omarchy-configuration/backups/plugins").glob("instrument-cluster.*"))
        self.assertEqual(len(backups), 1)
        self.assertEqual((backups[0] / "preserve.txt").read_text(), "original plugin")
        self.assertTrue((target / ".git").is_dir())
        updated = json.loads(config.read_text())
        self.assertEqual(updated["bar"]["position"], "left")
        self.assertEqual(updated["bar"]["centerAnchor"], "instrument-cluster")


if __name__ == "__main__":
    unittest.main()
