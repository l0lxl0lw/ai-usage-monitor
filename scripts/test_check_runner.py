#!/usr/bin/env python3
import pathlib
import tempfile
import unittest
from unittest.mock import patch
import subprocess
from check import main, validate


class EvidenceTests(unittest.TestCase):
    def run_xml(self, xml):
        with tempfile.TemporaryDirectory() as folder:
            path = pathlib.Path(folder) / 'report.xml'
            path.write_text(xml)
            validate(path, 'CoreTests', ['testOne', 'testTwo'])

    def test_good(self):
        self.run_xml('<testsuites><testsuite><testcase classname="MonitorTests.CoreTests" name="testOne"/><testcase classname="CoreTests" name="testTwo"/></testsuite></testsuites>')

    def test_rejections(self):
        one = '<testcase classname="CoreTests" name="testOne"/>'
        two = '<testcase classname="CoreTests" name="testTwo"/>'
        for xml in ['', 'not xml', '<testsuites/>', '<testsuite>'+one+'</testsuite>', '<testsuite>'+one+one+two+'</testsuite>', '<testsuite>'+one+two.replace('CoreTests', 'Foreign')+'</testsuite>', '<testsuite>'+one+two.replace('/>', '><skipped/></testcase>')+'</testsuite>', '<testsuite>'+one+two.replace('/>', '><failure/></testcase>')+'</testsuite>', '<testsuite failures="1">'+one+two+'</testsuite>']:
            with self.subTest(xml=xml), self.assertRaises(Exception):
                self.run_xml(xml)

    def test_missing_report(self):
        with tempfile.TemporaryDirectory() as folder, self.assertRaises(FileNotFoundError):
            validate(pathlib.Path(folder) / 'missing.xml', 'CoreTests', ['testOne'])

    def test_process_failure_never_prints_marker(self):
        with patch('sys.argv', ['check.py', 'tests', 'CoreTests']), \
             patch('check.subprocess.run', side_effect=subprocess.CalledProcessError(1, ['swift', 'test'])), \
             patch('builtins.print') as output, self.assertRaises(subprocess.CalledProcessError):
            main()
        output.assert_not_called()


if __name__ == '__main__':
    result = unittest.TextTestRunner().run(unittest.defaultTestLoader.loadTestsFromTestCase(EvidenceTests))
    if not result.wasSuccessful():
        raise SystemExit(1)
    print('PASS check-runner')
