"""Generate synthetic raw_medical_claim_lines.csv (Version 1 schema, 26 columns).

Reads raw_members.csv, raw_plans.csv, raw_eligibility_segments.csv and writes
claim lines that satisfy the project's V1 business rules. Deterministic (seeded).
"""
import csv, math, random, sys
from datetime import date, datetime, timedelta

random.seed(20260930)
SRC = sys.argv[1] if len(sys.argv) > 1 else "."
OUT = sys.argv[2] if len(sys.argv) > 2 else "raw_medical_claim_lines.csv"
DATA_END = date(2026, 6, 30)      # last service date covered by eligibility
AS_OF = date(2026, 8, 31)         # data cutoff: nothing received/paid/updated after this

def d(s): return date.fromisoformat(s) if s else None
def rd(a, b): return a + timedelta(days=random.randint(0, (b - a).days))

members = {r["member_id"]: r for r in csv.DictReader(open(f"{SRC}/raw_members.csv"))}
plans = {r["plan_id"]: r for r in csv.DictReader(open(f"{SRC}/raw_plans.csv"))}
segments = list(csv.DictReader(open(f"{SRC}/raw_eligibility_segments.csv")))

# ---------- providers (NPI with valid Luhn check digit) ----------
used = set()
def npi():
    while True:
        base = [1] + [random.randint(0, 9) for _ in range(8)]
        total = 24
        for i, dgt in enumerate(reversed(base)):
            if i % 2 == 0:
                dgt *= 2
                dgt = dgt - 9 if dgt > 9 else dgt
            total += dgt
        n = "".join(map(str, base)) + str((10 - total % 10) % 10)
        if n not in used:
            used.add(n); return n

STATES = ["NJ", "NY", "PA", "DE"]
def group(n_clin): return {"npi": npi(), "clinicians": [npi() for _ in range(n_clin)]}
prov = {s: {
    "pcp": [group(random.randint(3, 6)) for _ in range(8)],
    "specialty": [group(random.randint(2, 4)) for _ in range(3)],   # PT / BH
    "er_phys": [group(random.randint(4, 6)) for _ in range(2)],
    "hospitalist": [group(random.randint(4, 6)) for _ in range(2)],
    "hosp": [npi() for _ in range(3)],
    "snf": [npi() for _ in range(4)],
} for s in STATES}
LABS = [npi() for _ in range(2)]

# ---------- member clinical profile ----------
def age_on(m, dt):
    b = d(m["date_of_birth"]); return dt.year - b.year - ((dt.month, dt.day) < (b.month, b.day))

CHRONIC = [  # code, prevalence by age band (<18, 18-44, 45-64, 65+)
    ("E11.9", (.01, .08, .18, .26)), ("I10", (.01, .12, .38, .60)), ("E78.5", (0, .08, .28, .45)),
    ("J44.9", (0, .02, .07, .12)), ("J45.909", (.09, .07, .07, .05)), ("F32.9", (.04, .10, .10, .09)),
    ("N18.30", (0, .01, .05, .15)), ("I50.9", (0, .005, .03, .10)),
]
def band(a): return 0 if a < 18 else 1 if a < 45 else 2 if a < 65 else 3
mem_chronic = {}
for mid, m in members.items():
    a = age_on(m, date(2025, 1, 1))
    mem_chronic[mid] = [c for c, p in CHRONIC if random.random() < p[band(a)]]

# ---------- fee schedule (Medicare-like allowed; Medicaid pays ~75%) ----------
FEE = {"99203": 115, "99204": 170, "99212": 57, "99213": 92, "99214": 130, "99215": 180,
       "99393": 110, "99394": 120, "99395": 125, "99396": 135, "99397": 145, "G0439": 135,
       "96372": 15, "J1030": 6, "93000": 17, "81002": 4, "36415": 3, "80053": 11, "85025": 8,
       "83036": 10, "80061": 13, "84443": 17, "97161": 100, "97110": 29, "97140": 27,
       "90791": 175, "90834": 105, "90837": 150, "99283": 70, "99284": 115, "99285": 165,
       "99223": 205, "99232": 75, "99238": 75}
FAC = {"99283": 250, "99284": 420, "99285": 650, "71046": 90, "74177": 330, "70450": 180,
       "77067": 110, "80053": 15, "85025": 10}

ACUTE_ADULT = ["J06.9", "J02.9", "R05.9", "M54.50", "R10.9", "N39.0", "R51.9", "K21.9", "L03.90"]
ACUTE_CHILD = ["J06.9", "J02.9", "H66.90", "R05.9", "J45.909", "R50.9"]
ER_DX = ["R07.9", "R10.9", "S93.401A", "J18.9", "N39.0", "R55", "R51.9"]
IP_DX = ["J18.9", "A41.9", "N39.0", "K35.80"]

# ---------- claim builder ----------
claims = []
def line(proc=None, rev=None, units=1, mod=None, dx=None, rend=None, allowed=0.0, cs=0.0):
    return dict(procedure_code=proc, revenue_code=rev, units=units, procedure_modifier=mod,
                dx=dx, rendering_provider_npi=rend, allowed=allowed, cs=cs)

def add_claim(mid, plan, seg_end, sfrom, sto, bprov, btype, bill_type, pos, lines):
    claims.append(dict(member_id=mid, plan=plan, sfrom=sfrom, sto=sto, billing_provider_npi=bprov,
                       billing_provider_type=btype, bill_type_code=bill_type,
                       place_of_service_code=pos, lines=lines))

def mult(plan): return 0.75 if plan["product_code"] == "MCD" else 1.0

def dx_list(mid, primary):
    others = [c for c in mem_chronic[mid] if c != primary]
    random.shuffle(others)
    k = random.choice([0, 1, 1, 2]) if others else 0
    return [primary] + others[:k]

def cost_share(plan, kind, allowed, days=1):
    """Member cost sharing by plan type. Medicaid and full-dual D-SNP: $0."""
    pc, cov = plan["product_code"], plan["coverage_type_code"]
    if pc == "MCD" or (pc == "DSNP" and cov == "FULL"):
        return 0.0
    if pc == "DSNP" and cov == "LIMITED":           # partial duals: Part B-style 20%
        return round(allowed * 0.20, 2)
    # Medicare Advantage copays
    cs = {"pcp": 10, "spec": 35, "er": 100, "pt": 20, "bh": 20, "img": 50, "ip_day": 300,
          "lab": 0, "prev": 0}.get(kind, 0)
    if kind == "ip_day": cs = 300 * min(days, 5)
    return float(min(cs, allowed))

def gen_segment(seg):
    mid = seg["member_id"]; m = members[mid]; plan = plans[seg["plan_id"]]; st = plan["state_code"]
    s0 = d(seg["effective_date"]); s1 = min(d(seg["term_date"]) or DATA_END, DATA_END)
    if s1 < s0: return
    months = ((s1 - s0).days + 1) / 30.44
    ch = mem_chronic[mid]; mm = mult(plan); aid = plan["aid_category_code"]
    ltc = aid == "LTC"
    def n(rate): # Poisson draw for events over the segment
        lam = rate * months / 12; k, p, L = 0, 1.0, math.exp(-lam)
        while True:
            p *= random.random()
            if p <= L: return k
            k += 1
    pcp = random.choice(prov[st]["pcp"])   # member keeps one PCP group within a segment

    # office visits
    for _ in range(n(2.0 + 1.2 * len(ch))):
        dt = rd(s0, s1); a = age_on(m, dt)
        rend = random.choice(pcp["clinicians"])
        prim = random.choice(ch) if ch and random.random() < .55 else random.choice(ACUTE_CHILD if a < 18 else ACUTE_ADULT)
        em = random.choices(["99212", "99213", "99214", "99215"], [15, 45, 32, 8])[0]
        dx = dx_list(mid, prim); al = round(FEE[em] * mm, 2)
        ls = []
        extra = random.random()
        if extra < .08 and a >= 18:     # injection with separately identifiable E/M -> modifier 25
            ls.append(line(em, None, 1, "25", dx, rend, al, cost_share(plan, "pcp", al)))
            ls.append(line("96372", None, 1, None, dx, rend, round(FEE["96372"] * mm, 2)))
            u = random.choice([1, 2])
            ls.append(line("J1030", None, u, None, dx, rend, round(FEE["J1030"] * u * mm, 2)))
        else:
            ls.append(line(em, None, 1, None, dx, rend, al, cost_share(plan, "pcp", al)))
            if extra < .20 and a >= 40:
                ls.append(line("93000", None, 1, None, dx, rend, round(FEE["93000"] * mm, 2)))
            elif extra < .28:
                ls.append(line("81002", None, 1, None, dx, rend, round(FEE["81002"] * mm, 2)))
        add_claim(mid, plan, s1, dt, dt, pcp["npi"], "PHYS", None, "11", ls)

    # annual preventive visit
    for _ in range(n(0.6)):
        dt = rd(s0, s1); a = age_on(m, dt); rend = random.choice(pcp["clinicians"])
        if plan["program_type_code"] == "MEDICARE" and a >= 65: code = "G0439"
        else: code = "99393" if a < 12 else "99394" if a < 18 else "99395" if a < 40 else "99396" if a < 65 else "99397"
        dx = ["Z00.129" if a < 18 else "Z00.00"] + ch[:1]
        al = round(FEE[code] * mm, 2)
        add_claim(mid, plan, s1, dt, dt, pcp["npi"], "PHYS", None, "11",
                  [line(code, None, 1, None, dx, rend, al, cost_share(plan, "prev", al))])

    # lab panels (independent lab, no rendering provider)
    for _ in range(n(0.45 + 0.45 * len(ch))):
        dt = rd(s0, s1)
        prim = random.choice(ch) if ch else "Z00.00" if age_on(m, dt) >= 18 else "Z00.129"
        tests = ["36415"] + random.sample(["80053", "85025", "83036", "80061", "84443"], random.randint(1, 3))
        if "E11.9" not in ch and "83036" in tests and len(tests) > 2: tests.remove("83036")
        ls = [line(t, None, 1, None, [prim], None, round(FEE[t] * mm, 2)) for t in tests]
        add_claim(mid, plan, s1, dt, dt, random.choice(LABS), "LAB", None, "81", ls)

    # outpatient imaging (hospital facility claim: bill type 131, no POS)
    for _ in range(n(0.25)):
        dt = rd(s0, s1); a = age_on(m, dt)
        if m["gender_code"] == "F" and a >= 40 and random.random() < .4: proc, rev, dx = "77067", "0403", "Z12.31"
        else: proc, rev, dx = random.choice([("71046", "0324", "R05.9"), ("74177", "0352", "R10.9"), ("70450", "0351", "R51.9")])
        al = round(FAC[proc] * mm, 2)
        add_claim(mid, plan, s1, dt, dt, random.choice(prov[st]["hosp"]), "HOSP", "131", None,
                  [line(proc, rev, 1, None, dx_list(mid, dx), None, al, cost_share(plan, "img", al))])

    # ER visit: facility claim + ER physician professional claim
    for _ in range(n(0.30 + (0.15 if a_age(m) >= 65 else 0))):
        dt = rd(s0, s1); lvl = random.choices(["99283", "99284", "99285"], [40, 40, 20])[0]
        dx = dx_list(mid, random.choice(ER_DX))
        fal = round(FAC[lvl] * mm, 2)
        ls = [line(lvl, "0450", 1, None, dx, None, fal, cost_share(plan, "er", fal))]
        if random.random() < .6:
            for t in random.sample(["80053", "85025"], random.randint(1, 2)):
                ls.append(line(t, "0301", 1, None, dx, None, round(FAC[t] * mm, 2)))
        if dx[0] in ("R07.9", "J18.9") or random.random() < .25:
            ls.append(line("71046", "0324", 1, None, dx, None, round(FAC["71046"] * mm, 2)))
        if random.random() < .5:
            ls.append(line(None, "0250", 1, None, dx, None, round(random.uniform(20, 180) * mm, 2)))
        add_claim(mid, plan, s1, dt, dt, random.choice(prov[st]["hosp"]), "HOSP", "131", None, ls)
        g = random.choice(prov[st]["er_phys"]); pal = round(FEE[lvl] * mm, 2)
        add_claim(mid, plan, s1, dt, dt, g["npi"], "PHYS", None, "23",
                  [line(lvl, None, 1, None, dx, random.choice(g["clinicians"]), pal)])

    # inpatient stay: facility claim (111) + hospitalist professional claim; stay fits in segment
    ip_rate = 0.05 + 0.04 * len(ch) + (0.05 if a_age(m) >= 65 else 0)
    for _ in range(n(ip_rate)):
        los = random.choices([2, 3, 4, 5, 6, 8], [25, 25, 20, 15, 10, 5])[0]
        if (s1 - s0).days < los: continue
        sfrom = rd(s0, s1 - timedelta(days=los)); sto = sfrom + timedelta(days=los)
        prim = "I50.9" if "I50.9" in ch and random.random() < .5 else "J44.1" if "J44.9" in ch and random.random() < .4 else random.choice(IP_DX)
        dx = dx_list(mid, prim)
        rb = round(1200 * los * mm, 2)
        ls = [line(None, "0120", los, None, dx, None, rb, cost_share(plan, "ip_day", rb, los)),
              line(None, "0250", 1, None, dx, None, round(random.uniform(300, 1500) * mm, 2)),
              line(None, "0300", 1, None, dx, None, round(random.uniform(200, 800) * mm, 2))]
        if random.random() < .6: ls.append(line(None, "0320", 1, None, dx, None, round(random.uniform(150, 400) * mm, 2)))
        if random.random() < .4: ls.append(line(None, "0730", 1, None, dx, None, round(80 * mm, 2)))
        add_claim(mid, plan, s1, sfrom, sto, random.choice(prov[st]["hosp"]), "HOSP", "111", None, ls)
        g = random.choice(prov[st]["hospitalist"]); rend = random.choice(g["clinicians"])
        pls = [line("99223", None, 1, None, dx, rend, round(FEE["99223"] * mm, 2))]
        if los > 1: pls.append(line("99232", None, los - 1, None, dx, rend, round(FEE["99232"] * (los - 1) * mm, 2)))
        pls.append(line("99238", None, 1, None, dx, rend, round(FEE["99238"] * mm, 2)))
        add_claim(mid, plan, s1, sfrom, sto, g["npi"], "PHYS", None, "21", pls)

    # physical therapy episode
    if n(0.08):
        g = random.choice(prov[st]["specialty"]); rend = random.choice(g["clinicians"])
        dx = dx_list(mid, random.choice(["M54.50", "M25.561", "M25.511"]))
        start = rd(s0, s1)
        for i in range(random.randint(4, 10)):
            dt = start + timedelta(days=i * random.randint(3, 5))
            if dt > s1: break
            ls = []
            if i == 0:
                al = round(FEE["97161"] * mm, 2); ls.append(line("97161", None, 1, "GP", dx, rend, al, cost_share(plan, "pt", al)))
            else:
                u = random.randint(2, 3); al = round(FEE["97110"] * u * mm, 2)
                ls.append(line("97110", None, u, "GP", dx, rend, al, cost_share(plan, "pt", al)))
                if random.random() < .5: ls.append(line("97140", None, 1, "GP", dx, rend, round(FEE["97140"] * mm, 2)))
            add_claim(mid, plan, s1, dt, dt, g["npi"], "PHYS", None, "11", ls)

    # behavioral health episode
    if n(0.07 + (0.15 if "F32.9" in ch else 0)):
        g = random.choice(prov[st]["specialty"]); rend = random.choice(g["clinicians"])
        a = age_on(m, s0)
        prim = "F32.9" if "F32.9" in ch else random.choice(["F90.2", "F41.1"] if a < 18 else ["F41.1", "F43.10", "F33.1"])
        dx = dx_list(mid, prim); start = rd(s0, s1)
        for i in range(random.randint(3, 10)):
            dt = start + timedelta(days=i * random.choice([7, 7, 14]))
            if dt > s1: break
            code = "90791" if i == 0 else random.choice(["90834", "90834", "90837"])
            al = round(FEE[code] * mm, 2)
            add_claim(mid, plan, s1, dt, dt, g["npi"], "PHYS", None, "11",
                      [line(code, None, 1, None, dx, rend, al, cost_share(plan, "bh", al))])

    # nursing facility: LTC members, one interim claim per calendar month (21x)
    if ltc and random.random() < .7:
        snf = random.choice(prov[st]["snf"]); dx = dx_list(mid, random.choice(ch) if ch else "R54")
        cur = s0; first = True
        while cur <= s1:
            mend = (date(cur.year + (cur.month == 12), cur.month % 12 + 1, 1) - timedelta(days=1))
            end = min(mend, s1); days = (end - cur).days + 1
            last = end == s1 and d(seg["term_date"]) is not None and d(seg["term_date"]) <= DATA_END
            bt = "212" if first else "214" if last else "213"
            al = round(250 * days * mm, 2)
            add_claim(mid, plan, s1, cur, end, snf, "SNF", bt, None,
                      [line(None, "0120", days, None, dx, None, al)])
            cur = end + timedelta(days=1); first = False

def a_age(m): return age_on(m, date(2025, 1, 1))

for seg in segments:
    gen_segment(seg)

# ---------- adjudication, dates, cutoff ----------
def ts(dt, lo_h=7, hi_h=19):
    return datetime(dt.year, dt.month, dt.day, random.randint(lo_h, hi_h - 1), random.randint(0, 59), random.randint(0, 59))

final = []
for c in claims:
    lag = int(random.lognormvariate(2.6, 0.7)) + 2          # median ~15 days to receipt
    recv = c["sto"] + timedelta(days=lag)
    denied = random.random() < 0.07
    if denied:
        paid = None; decided = recv + timedelta(days=random.randint(5, 25))
    else:
        paid = recv + timedelta(days=random.randint(7, 30)); decided = paid
    upd_day = decided + timedelta(days=random.choice([0, 0, 0, 1, 2]))
    if random.random() < .05: upd_day += timedelta(days=random.randint(10, 90))   # later reprocessing
    if upd_day > AS_OF:
        if decided > AS_OF: continue        # not yet adjudicated at cutoff -> not in extract
        upd_day = AS_OF
    c.update(recv=recv, paid=paid, denied=denied, updated_at=ts(upd_day))
    final.append(c)

final.sort(key=lambda c: (c["recv"], c["member_id"], c["sfrom"]))
rows = []
for i, c in enumerate(final, 1):
    cid = f"C{i:07d}"
    for ln, l in enumerate(c["lines"], 1):
        allowed = 0.0 if c["denied"] else l["allowed"]
        cs = 0.0 if c["denied"] else min(l["cs"], allowed)
        paid_amt = 0.0 if c["denied"] else round(allowed - cs, 2)
        billed = round(max(l["allowed"], 1.0) * random.uniform(1.6, 3.2), 2)
        dx = l["dx"] + [None, None]
        rows.append({
            "claim_id": cid, "claim_line_number": ln, "member_id": c["member_id"],
            "claim_type_code": "M", "claim_status_code": "DENIED" if c["denied"] else "PAID",
            "billing_provider_npi": c["billing_provider_npi"], "rendering_provider_npi": l["rendering_provider_npi"],
            "billing_provider_type": c["billing_provider_type"], "bill_type_code": c["bill_type_code"],
            "service_from_date": c["sfrom"].isoformat(), "service_to_date": c["sto"].isoformat(),
            "received_date": c["recv"].isoformat(), "paid_date": c["paid"].isoformat() if c["paid"] else None,
            "place_of_service_code": c["place_of_service_code"], "revenue_code": l["revenue_code"],
            "procedure_code": l["procedure_code"], "procedure_modifier": l["procedure_modifier"],
            "units": l["units"], "diagnosis_code_1": dx[0], "diagnosis_code_2": dx[1], "diagnosis_code_3": dx[2],
            "billed_amount": f"{billed:.2f}", "allowed_amount": f"{allowed:.2f}",
            "paid_amount": f"{paid_amt:.2f}", "member_responsibility_amount": f"{cs:.2f}",
            "updated_at": c["updated_at"].strftime("%Y-%m-%d %H:%M:%S"),
        })

with open(OUT, "w", newline="") as f:
    w = csv.DictWriter(f, fieldnames=list(rows[0].keys()))
    w.writeheader(); w.writerows(rows)
print(f"{len(final)} claims, {len(rows)} lines -> {OUT}")
