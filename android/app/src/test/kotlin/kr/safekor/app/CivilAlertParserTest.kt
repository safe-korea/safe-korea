package kr.safekor.app

import org.junit.Assert.*
import org.junit.Test

class CivilAlertParserTest {
    @Test fun requiresSystemPublisherAndMatchingUid() {
        assertTrue(CivilAlertParser.trustedSource("com.android.cellbroadcastreceiver", true, true))
        assertTrue(CivilAlertParser.trustedSource("com.google.android.cellbroadcastreceiver", true, true))
        assertFalse(CivilAlertParser.trustedSource("kr.safekor.app", true, true))
        assertFalse(CivilAlertParser.trustedSource("com.android.cellbroadcastreceiver", false, true))
        assertFalse(CivilAlertParser.trustedSource("com.android.cellbroadcastreceiver", true, false))
    }
    @Test fun acceptsOnlyExplicitUnambiguousIssuance() {
        val cases = mapOf("공습경보" to "air", "경계경보" to "watch", "화생방경보" to "cbrn", "핵경보" to "nuclear", "화학공격경보" to "chemical", "생물학공격경보" to "biological")
        for ((label, kind) in cases) assertEquals(kind, CivilAlertParser.classify("서울 지역 $label 발령합니다. 정부 안내를 확인하세요."))
        assertNull(CivilAlertParser.classify("경계경보 및 공습경보 발령합니다."))
        assertNull(CivilAlertParser.classify("공습경보 행동요령: 지하시설로 이동하세요."))
    }
    @Test fun rejectsTrainingCorrectionsConditionalAndOrdinaryDisasters() {
        val excluded = listOf("훈련 공습경보 발령합니다", "모의 공습경보 발령합니다", "공습경보 발령 예정", "공습경보 발령시 대피하세요", "공습경보 발령할 경우 대피하세요", "공습경보 발령되지 않았습니다", "공습경보 발령되었습니다. 오발령입니다", "공습경보 해제 발령합니다", "화재 공습경보 발령합니다", "화학물질 누출 사고", "태풍 경보 발령합니다", "test 공습경보 발령합니다")
        for (text in excluded) assertNull(text, CivilAlertParser.classify(text))
        assertNull(CivilAlertParser.classify("공습경보 발령합니다" + "가".repeat(8000)))
    }
    @Test fun rejectsMissingStaleAndFutureTimestamps() {
        val now = 1_800_000_000_000L
        assertTrue(CivilAlertParser.fresh(now, now, now))
        assertTrue(CivilAlertParser.fresh(now - 120000, now, now))
        assertFalse(CivilAlertParser.fresh(0, now, now))
        assertFalse(CivilAlertParser.fresh(now, 0, now))
        assertFalse(CivilAlertParser.fresh(now - 120001, now, now))
        assertFalse(CivilAlertParser.fresh(now, now - 120001, now))
        assertFalse(CivilAlertParser.fresh(now + 30001, now, now))
    }
}
