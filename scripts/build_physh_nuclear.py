#!/usr/bin/env python3
"""Build kb-wiki/physh-nuclear.yaml from data/physh.json (PhySH SKOS dump)."""

import json
import re
import yaml
from pathlib import Path

PHYSH_JSON = Path(__file__).resolve().parent.parent / "data" / "physh.json"
OUTPUT = Path(__file__).resolve().parent.parent / "kb-wiki" / "physh-nuclear.yaml"

NP_DISCIPLINE_UUID = "0213a5a0-0742-43f3-804b-3ccea08a13c0"

def load_physh():
    with open(PHYSH_JSON) as f:
        return json.load(f)

def get_pref_label(entry):
    for k in entry:
        if 'prefLabel' in k:
            vals = entry[k]
            if isinstance(vals, list) and vals:
                v = vals[0]
                return v.get('@value', '') if isinstance(v, dict) else str(v)
    return ''

def get_alt_labels(entry):
    labels = []
    for k in entry:
        if 'altLabel' in k:
            vals = entry[k]
            if not isinstance(vals, list):
                vals = [vals]
            for v in vals:
                labels.append(v.get('@value', '') if isinstance(v, dict) else str(v))
    return labels

def get_broader(entry):
    for k in entry:
        if 'broader' in k.lower():
            vals = entry[k]
            if not isinstance(vals, list):
                vals = [vals]
            return [v['@id'].split('/')[-1] if isinstance(v, dict) else v.split('/')[-1] for v in vals]
    return []

def get_narrower(entry):
    for k in entry:
        if 'narrower' in k.lower():
            vals = entry[k]
            if not isinstance(vals, list):
                vals = [vals]
            return [v['@id'].split('/')[-1] if isinstance(v, dict) else v.split('/')[-1] for v in vals]
    return []

def slugify(text):
    s = text.lower().strip()
    s = re.sub(r'[^a-z0-9\s-]', '', s)
    s = re.sub(r'\s+', '-', s)
    s = re.sub(r'-+', '-', s)
    return s.strip('-')


def main():
    data = load_physh()

    id_to_entry = {}
    for entry in data:
        eid = entry.get('@id', '')
        if isinstance(eid, str):
            id_to_entry[eid.split('/')[-1]] = entry

    # Step 1: extract 31 core NP concepts
    np_core_uuids = set()
    for entry in data:
        eid = entry.get('@id', '')
        if NP_DISCIPLINE_UUID in eid and 'ConceptScheme' in str(entry.get('@type')):
            hasc_key = None
            for k in entry:
                if 'hasConcept' in k:
                    hasc_key = k
                    break
            if hasc_key:
                for hc in entry[hasc_key]:
                    np_core_uuids.add(hc['@id'].split('/')[-1])

    print(f"Core NP concepts: {len(np_core_uuids)}")

    # Step 2: build broader-to-narrower reverse map and find all descendants
    narrower_map = {}
    for entry in data:
        uuid = entry.get('@id', '').split('/')[-1]
        for buuid in get_broader(entry):
            narrower_map.setdefault(buuid, []).append(uuid)

    all_np_uuids = set(np_core_uuids)
    queue = list(np_core_uuids)
    while queue:
        current = queue.pop()
        for child in narrower_map.get(current, []):
            if child not in all_np_uuids:
                all_np_uuids.add(child)
                queue.append(child)

    print(f"Total NP concepts (core + descendants): {len(all_np_uuids)}")

    # Step 3: neighbor whitelist search
    # Exact-match labels for neighbor concepts outside NP
    neighbor_labels_exact = [
        # Astrophysics cross-overs for nucl-th
        "Neutron stars & pulsars",
        "Big bang nucleosynthesis",
        # Particles & Fields
        "Effective field theory",
    ]
    neighbor_uuids = set()
    neighbor_entries = []
    for entry in data:
        uuid = entry.get('@id', '').split('/')[-1]
        if uuid in all_np_uuids:
            continue
        pref = get_pref_label(entry)
        if pref in neighbor_labels_exact:
            neighbor_uuids.add(uuid)
            neighbor_entries.append((uuid, pref))

    # Also include descendants of neighbor concepts
    extra_neighbors = set()
    for nuuid in list(neighbor_uuids):
        queue_n = [nuuid]
        while queue_n:
            current = queue_n.pop()
            for child in narrower_map.get(current, []):
                if child not in all_np_uuids and child not in neighbor_uuids and child not in extra_neighbors:
                    extra_neighbors.add(child)
                    queue_n.append(child)
    neighbor_uuids |= extra_neighbors

    print(f"Neighbor concepts: {len(neighbor_uuids)}")
    for uuid, label in neighbor_entries:
        print(f"  {label} ({uuid[:8]}...)")

    # Step 4: build YAML entries
    concepts = {}

    for uuid in sorted(all_np_uuids | neighbor_uuids):
        entry = id_to_entry.get(uuid)
        if not entry:
            continue
        if 'ConceptScheme' in str(entry.get('@type', '')):
            continue

        label = get_pref_label(entry)
        if not label:
            continue

        slug = slugify(label)
        if not slug:
            continue

        broader_uuids = get_broader(entry)
        narrower_in_np = [c for c in narrower_map.get(uuid, []) if c in all_np_uuids or c in neighbor_uuids]

        is_neighbor = uuid in neighbor_uuids
        in_np = uuid in all_np_uuids

        concepts[uuid] = {
            'slug': slug,
            'physh_id': uuid,
            'label': label,
            'broader': [],
            'narrower': [],
            'match': [],
            'neighbor': is_neighbor,
        }

    # Second pass: fill broader/narrower by slug
    for uuid, cdata in concepts.items():
        entry = id_to_entry.get(uuid)
        if not entry:
            continue
        for buuid in get_broader(entry):
            if buuid in concepts:
                cdata['broader'].append(concepts[buuid]['slug'])
        for nuuid in narrower_map.get(uuid, []):
            if nuuid in concepts:
                cdata['narrower'].append(concepts[nuuid]['slug'])

    # Step 5: seed match queries from prefLabel + altLabels
    # Then apply hand rules

    # Bare words that should ONLY match on title/abstract tiers, never fulltext
    DANGEROUS_WORDS = {
        'spin', 'parity', 'mass', 'energy', 'momentum', 'density',
        'isospin', 'symmetry', 'strength', 'width', 'cross-section',
        'lifetime', 'binding', 'excitation', 'shell', 'model',
    }

    for uuid, cdata in concepts.items():
        entry = id_to_entry.get(uuid)
        if not entry:
            continue
        label = cdata['label']
        alts = get_alt_labels(entry)

        # Collect all candidate phrases
        phrases = [label]

        # Add altLabels (skip ones that are just acronym expansions containing the label)
        for a in alts:
            if a and a.lower() != label.lower():
                phrases.append(a)

        # Dedupe
        seen = set()
        deduped = []
        for p in phrases:
            pl = p.lower().strip()
            if pl and pl not in seen:
                seen.add(pl)
                deduped.append(p)
        phrases = deduped

        # Generate match strings
        matches = []
        for p in phrases:
            is_dangerous = any(
                p.lower().strip() == dw or p.lower().strip() in ('shell-model',) or
                (len(p.split()) == 1 and p.lower() in DANGEROUS_WORDS)
                for dw in DANGEROUS_WORDS
            )
            if is_dangerous:
                matches.append({'query': f'"{p}"', 'tiers': [1, 2]})
            else:
                matches.append({'query': f'"{p}"', 'tiers': [1, 2, 3]})

        cdata['match'] = matches

    # Step 6: hand-crafted overrides
    hand_rules = {
        'breakup-reactions': [
            ('"inclusive breakup"', [1, 2, 3]),
            ('"elastic breakup"', [1, 2, 3]),
            ('"nonelastic breakup"', [1, 2, 3]),
            ('"non-elastic breakup"', [1, 2, 3]),
            ('"breakup cross section"', [1, 2, 3]),
        ],
        'nuclear-fusion': [
            ('"complete fusion"', [1, 2, 3]),
            ('"incomplete fusion"', [1, 2, 3]),
            ('"fusion suppression"', [1, 2, 3]),
        ],
        'direct-reactions': [
            ('"transfer reaction"', [1, 2, 3]),
            ('"stripping reaction"', [1, 2, 3]),
            ('"pickup reaction"', [1, 2, 3]),
        ],
    }

    # Find concept UUIDs by slug
    slug_to_uuid = {c['slug']: uuid for uuid, c in concepts.items()}

    for slug, extra_matches in hand_rules.items():
        uuid = slug_to_uuid.get(slug)
        if uuid and uuid in concepts:
            for query, tiers in extra_matches:
                concepts[uuid]['match'].append({'query': query, 'tiers': tiers})

    # Step 7: write YAML
    output_concepts = []
    for uuid in sorted(concepts.keys()):
        cdata = concepts[uuid]
        output_concepts.append(cdata)

    yaml_structure = {
        'physh_version': '2.8.0',
        'discipline': 'Nuclear Physics',
        'discipline_physh_id': NP_DISCIPLINE_UUID,
        'total_concepts': len(output_concepts),
        'matching_tiers': {
            1: 'phrase hits title',
            2: 'phrase hits abstract',
            3: 'fulltext only; requires >= 2 distinct match phrases OR one phrase hitting >= 3 times',
        },
        'negative_filter': {
            'rule': 'papers with primary_cat starting with hep- or astro-ph can only receive reaction-family concepts at tier 1 or 2, never on a tier-3 fulltext match',
            'reaction_family_slugs': [
                'nuclear-reactions', 'direct-reactions', 'breakup-reactions',
                'knockout-reactions', 'fusion-reactions', 'nuclear-fusion',
                'transfer-reactions', 'coulomb-excitation', 'optical-model',
                'few-body-systems', 'relativistic-heavy-ion-collisions',
                'heavy-ion-nuclear-reactions',
            ],
        },
        'dangerous_fulltext_words': sorted(DANGEROUS_WORDS),
        'concepts': output_concepts,
    }

    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    with open(OUTPUT, 'w') as f:
        yaml.dump(yaml_structure, f, allow_unicode=True, default_flow_style=False,
                  sort_keys=False, width=200)

    print(f"\nWrote {OUTPUT}")
    print(f"Total concepts in YAML: {len(output_concepts)}")
    print(f"Of which neighbors: {sum(1 for c in output_concepts if c.get('neighbor'))}")


if __name__ == '__main__':
    main()
