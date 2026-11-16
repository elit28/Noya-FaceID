#!/usr/bin/env python3
"""Vérifie que chaque texte visible de l'app existe en français et en anglais.

1. Les fichiers Localizable.strings et InfoPlist.strings ont exactement les mêmes clés
   dans toutes les langues, sans valeur vide.
2. Chaque chaîne littérale des sources de l'app (Sources/NoyaFace) est une clé traduite,
   sauf les identifiants techniques (Identifiers.swift) et les contextes non traduits
   (verbatim:, systemName:, keyboardShortcut(, forKey:…) ou les lignes marquées « // noloc ».
Usage : python3 scripts/check-localizations.py
"""
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
LANGUAGES = ["fr", "en"]
TABLES = ["Localizable.strings", "InfoPlist.strings"]
APP_SOURCES = ROOT / "Sources" / "NoyaFace"
EXCLUDED_FILES = {"Identifiers.swift"}
NON_LOCALIZED_CONTEXTS = ("verbatim: ", "systemName: ", "symbol: ", "keyboardShortcut(", "forKey: ", "id: ",
                          "named: ", "withExtension: ", "forInfoDictionaryKey: ")
ENTRY = re.compile(r'^\s*"((?:[^"\\]|\\.)*)"\s*=\s*"((?:[^"\\]|\\.)*)"\s*;\s*$')
LITERAL = re.compile(r'"((?:[^"\\]|\\.)*)"')


def load_table(path):
    entries = {}
    for number, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        stripped = line.strip()
        if not stripped or stripped.startswith(("/*", "*", "//")):
            continue
        match = ENTRY.match(line)
        if not match:
            raise SystemExit(f"{path}:{number}: ligne illisible : {line}")
        key, value = match.group(1), match.group(2)
        if key in entries:
            raise SystemExit(f"{path}:{number}: clé en double : {key}")
        entries[key] = value
    return entries


INTERPOLATION = re.compile(r"\\\([^)]*\)")


def localization_keys(text):
    """Clés possibles d'un texte : chaque interpolation \\(…) devient %@ ou %lld."""
    parts = INTERPOLATION.split(text)
    candidates = [parts[0]]
    for part in parts[1:]:
        candidates = [c + spec + part for c in candidates for spec in ("%@", "%lld")]
    return candidates


def main():
    errors = []
    tables = {}
    for table in TABLES:
        for lang in LANGUAGES:
            path = ROOT / "packaging" / f"{lang}.lproj" / table
            if not path.exists():
                errors.append(f"fichier manquant : {path.relative_to(ROOT)}")
                continue
            tables[(table, lang)] = load_table(path)
        reference = tables.get((table, LANGUAGES[0]), {})
        for lang in LANGUAGES[1:]:
            other = tables.get((table, lang), {})
            for key in sorted(set(reference) - set(other)):
                errors.append(f"{lang}/{table} : traduction manquante pour « {key} »")
            for key in sorted(set(other) - set(reference)):
                errors.append(f"{lang}/{table} : clé inconnue en {LANGUAGES[0]} « {key} »")
        for lang in LANGUAGES:
            for key, value in tables.get((table, lang), {}).items():
                if not value.strip():
                    errors.append(f"{lang}/{table} : valeur vide pour « {key} »")

    keys = set(tables.get(("Localizable.strings", "fr"), {}))
    for source in sorted(APP_SOURCES.rglob("*.swift")):
        if source.name in EXCLUDED_FILES:
            continue
        for number, line in enumerate(source.read_text(encoding="utf-8").splitlines(), 1):
            stripped = line.strip()
            if stripped.startswith("//") or "// noloc" in line:
                continue
            for match in LITERAL.finditer(line):
                text = match.group(1)
                before = line[:match.start()]
                if not text or before.endswith(NON_LOCALIZED_CONTEXTS):
                    continue
                if not any(candidate in keys for candidate in localization_keys(text)):
                    errors.append(f"{source.relative_to(ROOT)}:{number}: texte non traduit « {text} »")

    if errors:
        print("Traductions incomplètes :", file=sys.stderr)
        for error in errors:
            print(f"  - {error}", file=sys.stderr)
        return 1
    print(f"Traductions complètes : {len(keys)} textes en {', '.join(LANGUAGES)}.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
