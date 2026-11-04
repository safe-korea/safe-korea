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
        assertEquals("air", CivilAlertParser.classify("경계경보 및 공습경보 발령합니다."))
        assertNull(CivilAlertParser.classify("공습경보 행동요령: 지하시설로 이동하세요."))
    }
    @Test fun acceptsRealisticCivilDefenseWording() {
        val cases = mapOf(
            "[서울특별시] 오늘 6시 32분 서울지역에 경계경보 발령. 국민 여러분께서는 대피할 준비를 하시고, 어린이와 노약자가 우선 대피할 수 있도록 해 주시기 바랍니다." to "watch",
            "[행정안전부] 공습경보 발령. 가정에서는 창문을 닫고 지하로 대피하십시오." to "air",
            "[행정안전부] 화생방경보 발령. 유독가스 누출 우려, 방독면을 착용하고 높은 곳으로 대피하세요." to "cbrn",
            "[행정안전부] 현재 서울 전역 공습경보 발령 중. 지하시설로 대피하세요." to "air",
            "[행정안전부] 서울지역 공습경보가 발령되었으니 즉시 대피하시기 바랍니다." to "air",
            "[행정안전부] 경계경보에 이어 공습경보 발령. 즉시 대피하세요." to "air",
            "[행정안전부] 공습경보 발령, 사고 위험이 있으니 엘리베이터를 이용하지 마세요." to "air",
        )
        for ((text, kind) in cases) assertEquals(text, kind, CivilAlertParser.classify(text))
    }
    @Test fun rejectsTrainingCorrectionsConditionalAndOrdinaryDisasters() {
        val excluded = listOf("훈련 공습경보 발령합니다", "모의 공습경보 발령합니다", "공습경보 발령 예정", "공습경보 발령시 대피하세요", "공습경보 발령할 경우 대피하세요", "공습경보 발령되지 않았습니다", "공습경보 발령되었습니다. 오발령입니다", "공습경보 해제 발령합니다", "화재 공습경보 발령합니다", "화학물질 누출 사고", "태풍 경보 발령합니다", "test 공습경보 발령합니다", "공습경보 상황을 가정한 대피 안내를 발령합니다")
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
