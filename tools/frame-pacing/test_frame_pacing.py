import importlib.util
import math
from pathlib import Path
import tempfile
import unittest

spec = importlib.util.spec_from_file_location('pacing', Path(__file__).with_name('frame-pacing.py'))
pacing = importlib.util.module_from_spec(spec)
spec.loader.exec_module(pacing)


class PacingTests(unittest.TestCase):
    def csv(self, text):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / 'capture.csv'
            path.write_text(text)
            return pacing.load_csv(path)

    def test_versioned_mangohud_and_nanoseconds(self):
        rows = self.csv('v1\n0.8.2\nSYSTEM INFO\nos,cpu,gpu\nLinux,CPU,GPU\n'
                        'FRAME METRICS\nfps,frametime,elapsed\n60,16.667,1000000000\n60,16.667,1016667000\n')
        self.assertAlmostEqual(rows[1][0], 1.016667)
        self.assertEqual(len(rows), 2)

    def test_reject_bad_data_instead_of_silently_hiding_stutters(self):
        for value in ('nan', 'inf', '-1', '0', 'broken'):
            with self.subTest(value=value), self.assertRaises(ValueError):
                self.csv(f'fps,frametime\n60,16\n60,{value}\n60,16\n')

    def test_reject_summary_and_restarted_timestamps(self):
        for text in ('Average FPS,Average Frame Time\n60,16.67\n',
                     'fps,frametime,elapsed\n60,16,100\n60,16,99\n'):
            with self.assertRaises(ValueError):
                self.csv(text)

    def test_sparse_log_cannot_pass_as_per_frame(self):
        result = pacing.analyze([(i * .1, 16.667) for i in range(20)], per_frame=True)
        self.assertIn('INCOMPLETE', result['assessment'])
        self.assertIn('sparse', result['sampling_warning'])

    def test_steady_capture_does_not_claim_screen_smoothness(self):
        result = pacing.analyze([(i / 60, 1000 / 60) for i in range(100)], 60, True)
        self.assertEqual(result['long_samples'], 0)
        self.assertIn('visible smoothness unverified', result['assessment'])
        self.assertIn('UNKNOWN', result['scope'])

    def test_alternating_pacing_and_large_hitch(self):
        frames = [10, 20] * 50 + [100]
        elapsed = 0
        rows = []
        for frame in frames:
            elapsed += frame / 1000
            rows.append((elapsed, frame))
        result = pacing.analyze(rows, 60, True)
        self.assertIn('unevenness detected', result['assessment'])
        self.assertEqual(result['over_50_ms'], 1)
        self.assertEqual(result['largest_samples'][0]['sample'], 101)
        self.assertEqual(result['successive_difference_p95_ms'], 10)

    def test_config_allowlist(self):
        entries = pacing.settings('# fps_limit=1\nfps_limit=250,0\nexec=secret\nvsync=0\n', pacing.MANGO_KEYS)
        self.assertEqual([x['key'] for x in entries], ['fps_limit', 'vsync'])
        self.assertEqual(entries[0]['value'], '250,0')

    def test_process_privacy_and_inline_cap_list(self):
        with tempfile.TemporaryDirectory() as tmp:
            proc = Path(tmp)
            base = proc / '42'
            base.mkdir()
            (base / 'environ').write_bytes(b'SECRET=hidden\0MANGOHUD=1\0MANGOHUD_CONFIG=fps_limit=250,0,log_interval=0,exec=private\0')
            (base / 'cmdline').write_bytes(b'wine\0C:\\games\\witcher3.exe\0--password=private\0')
            (base / 'comm').write_text('witcher3.exe')
            (base / 'maps').write_text('abcd /lib/libMangoHud.so\n')
            result, _ = pacing.process(42, proc)
            self.assertNotIn('hidden', str(result))
            self.assertNotIn('private', str(result))
            self.assertEqual(result['mangohud_inline_requests'][0]['value'], '250,0')
            self.assertEqual(result['mapped_libraries'], ['libMangoHud.so'])

    def test_html_is_standalone_and_refuses_overwrite(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / 'report.html'
            rows = [(0, 16), (.016, 16)]
            result = pacing.analyze(rows)
            pacing.html_report(path, result, rows)
            self.assertIn('<svg', path.read_text())
            self.assertIn('UNKNOWN', path.read_text())
            with self.assertRaises(FileExistsError):
                pacing.html_report(path, result, rows)

    def test_invalid_target(self):
        import argparse
        for value in ('0', '-1', 'nan', 'inf'):
            with self.assertRaises(argparse.ArgumentTypeError):
                pacing.positive(value)

    def test_missing_optional_tool_is_reported(self):
        self.assertIn('unavailable', pacing.command(['/nonexistent/frame-pacing-test']))


if __name__ == '__main__':
    unittest.main()
