package kr.safekor.app

/** Conservative local relay; never infer an alarm from arbitrary app notifications. */
object CivilAlertParser {
    val sources = setOf("com.android.cellbroadcastreceiver", "com.google.android.cellbroadcastreceiver")
    fun trustedSource(pkg: String, systemApp: Boolean, uidMatches: Boolean) =
        pkg in sources && systemApp && uidMatches

    fun classify(text: String): String? {
        val t = text.lowercase().replace(Regex("\\s+"), "")
        if (t.length > 8000) return null
        val excluded = listOf("훈련", "연습", "모의", "테스트", "drill", "exercise", "test",
            "예정", "예고", "예시", "가정", "오발령", "잘못발령", "취소", "해제", "발령시", "발령할경우",
            "발령될경우", "발령된경우", "발령하지", "발령되지", "발령된것이아니", "화재", "산불", "태풍", "지진",
            "호우", "홍수", "폭염", "누출", "유출", "사고")
        if (excluded.any { t.contains(it) }) return null
        if (!Regex("발령(합니다|되었습니다|됐습니다|하였습니다|되었|됨|[.!]|$)").containsMatchIn(t)) return null
        val kinds = mutableSetOf<String>()
        if (t.contains("공습경보")) kinds.add("air")
        if (t.contains("경계경보")) kinds.add("watch")
        if (t.contains("화생방경보")) kinds.add("cbrn")
        if (t.contains("핵경보")) kinds.add("nuclear")
        if (t.contains("화학공격경보") || t.contains("화학무기공격경보")) kinds.add("chemical")
        if (t.contains("생물학공격경보") || t.contains("생물공격경보")) kinds.add("biological")
        return kinds.singleOrNull()
    }

    fun fresh(whenMs: Long, postMs: Long, now: Long): Boolean = whenMs > 0 && postMs > 0 &&
        now - whenMs in -30000L..120000L && now - postMs in -30000L..120000L
}
