package kr.safekor.app

/** Conservative local relay; never infer an alarm from arbitrary app notifications. */
object CivilAlertParser {
    val sources = setOf("com.android.cellbroadcastreceiver", "com.google.android.cellbroadcastreceiver")
    fun trustedSource(pkg: String, systemApp: Boolean, uidMatches: Boolean) =
        pkg in sources && systemApp && uidMatches

    // Words that make the whole message a drill, correction, conditional or non-war disaster.
    // Ordinary instruction words such as "가정에서는" or "가스 누출 우려" must not drop a real issuance.
    private val excluded = listOf("훈련", "연습", "모의", "테스트", "drill", "exercise", "test",
        "예정", "예고", "예시", "가정하", "가정한", "오발령", "잘못발령", "취소", "해제", "발령시", "발령할경우",
        "발령될경우", "발령된경우", "발령하지", "발령되지", "발령된것이아니", "화재", "산불", "태풍", "지진",
        "호우", "홍수", "폭염")
    private val issuance = Regex("발령(합니다|되었습니다|됐습니다|하였습니다|되었|됨|중|[.!,]|$)")
    private val labels = listOf(
        "공습경보" to "air", "경계경보" to "watch", "화생방경보" to "cbrn", "핵경보" to "nuclear",
        "화학공격경보" to "chemical", "화학무기공격경보" to "chemical",
        "생물학공격경보" to "biological", "생물공격경보" to "biological",
    )

    fun classify(text: String): String? {
        val t = text.lowercase().replace(Regex("\\s+"), "")
        if (t.length > 8000) return null
        if (excluded.any { t.contains(it) }) return null
        val issued = issuance.find(t) ?: return null
        // "X경보 발령": the alert named closest before the first issuance verb wins,
        // e.g. "경계경보에 이어 공습경보 발령" -> air.
        return labels.mapNotNull { (label, kind) ->
            val at = t.lastIndexOf(label, issued.range.first - 1)
            if (at >= 0) at to kind else null
        }.maxByOrNull { it.first }?.second
    }

    fun fresh(whenMs: Long, postMs: Long, now: Long): Boolean = whenMs > 0 && postMs > 0 &&
        now - whenMs in -30000L..120000L && now - postMs in -30000L..120000L
}
