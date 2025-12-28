CEFR = ["A1","A2","B1","B2","C1","C2"]

def harder(level: str) -> str:
    i = CEFR.index(level)
    return CEFR[min(i+1, len(CEFR)-1)]

def easier(level: str) -> str:
    i = CEFR.index(level)
    return CEFR[max(i-1, 0)]

def writing_score_to_cefr(score_0_to_15: int) -> str:
    if score_0_to_15 <= 4:
        return "A2"
    if score_0_to_15 <= 7:
        return "B1"
    if score_0_to_15 <= 11:
        return "B2"
    return "C1"
