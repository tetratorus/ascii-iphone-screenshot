from pathlib import Path
import sqlite3
import tempfile
import unittest
from datetime import datetime

import uptime


class UptimeTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.history = Path(self.tmp.name)
        with sqlite3.connect(self.history / "index.sqlite") as db:
            db.execute("CREATE TABLE frames(id INTEGER PRIMARY KEY, time REAL)")
            db.execute("CREATE VIRTUAL TABLE words USING fts5(text, content='', detail=none)")

    def add(self, stamp, text):
        with sqlite3.connect(self.history / "index.sqlite") as db:
            frame_id = db.execute("INSERT INTO frames(time) VALUES (?)", (stamp,)).lastrowid
            db.execute("INSERT INTO words(rowid,text) VALUES (?,?)", (frame_id, text))

    def testCountsUniqueWordsAndGapsWithoutReadingText(self):
        self.add(100, "hello hello world")
        self.add(160, "hello")
        self.add(1100, "a later screen")
        data = uptime.read_activity(self.history, 0, 1200, 1250)
        self.assertEqual(data["frames"], 3)
        self.assertEqual([b["words_per_frame"] for b in data["buckets"] if b["frames"]], [2, 1, 3])
        self.assertEqual(data["latest_age_seconds"], 150)
        self.assertEqual(data["gaps"][0], {"start": 160, "end": 1100, "seconds": 940})
        self.assertNotIn("hello", str(data))
        self.assertIn("NO RECENT CAPTURES", uptime.render(data, "running"))
        self.assertIn("not an uptime percentage", uptime.render(data, "running"))

    def testEmptyRangeStillShowsLatestCaptureAndStoppedService(self):
        self.add(1100, "screen")
        data = uptime.read_activity(self.history, 0, 600, 1120)
        self.assertEqual(data["frames"], 0)
        self.assertEqual(data["latest_capture"], 1100)
        self.assertIn("RECORDER STOPPED", uptime.render(data, "stopped"))
        self.assertEqual(sum(b["frames"] for b in data["buckets"]), 0)

    def testEmptyDatabaseAndTimeParsing(self):
        data = uptime.read_activity(self.history, 0, 600, 600)
        self.assertIn("NO SAVED FRAMES", uptime.render(data, "running"))
        self.assertEqual(uptime.parse_time("1h30m", 10000), 4600)
        self.assertEqual(uptime.parse_time("now", 10000), 10000)

    def testAxisHasSevenAlignedReadableTimeLabels(self):
        start = datetime(2026, 11, 16, 16, 0).timestamp()
        ticks, labels = uptime.time_axis(start, start + 3600, 60)
        self.assertEqual(ticks.count("┬"), 7)
        self.assertEqual(len(ticks), 60)
        self.assertEqual(labels.split(), ["16:00", "16:10", "16:20", "16:30", "16:40", "16:50", "17:00"])
        _, labels = uptime.time_axis(start, start + 60, 66)
        self.assertEqual(len(labels.split()), 7)
        self.assertIn("16:00:10", labels)

    def testZoomPanAndReturnToLive(self):
        view = uptime.View()
        self.assertEqual(view.span, 3600)
        start, end = view.window(7200)
        self.assertEqual((start, end), (3600, 7200))
        view.key("+", 7200)
        self.assertEqual(view.span, 1800)
        view.key("-", 7200)
        self.assertEqual(view.span, 3600)
        view.key("\x1b[D", 7200)
        self.assertEqual(view.window(9000), (1800, 5400))
        view.key("L", 9000)
        self.assertEqual(view.window(9000), (5400, 9000))
        for _ in range(20):
            view.key("+", 9000)
        self.assertEqual(view.span, 60)
        for _ in range(20):
            view.key("-", 9000)
        self.assertEqual(view.span, 604800)
        self.assertFalse(view.key("q", 9000))

    def testCaptureRunsKeepExactTimesAndEndBoundary(self):
        for stamp in (100, 105, 500, 600):
            self.add(stamp, "test")
        data = uptime.read_activity(self.history, 0, 600, 600, columns=60)
        self.assertEqual(data["capture_runs"], [
            {"start": 100, "end": 105, "frames": 2},
            {"start": 500, "end": 500, "frames": 1},
            {"start": 600, "end": 600, "frames": 1},
        ])
        self.assertEqual(data["buckets"][-1]["frames"], 1)
        self.assertEqual(sum(b["frames"] for b in data["buckets"]), 4)
        self.assertIn("Each cell = 10s", uptime.render(data, "running"))


if __name__ == "__main__":
    unittest.main()
