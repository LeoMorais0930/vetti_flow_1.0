from app.protheus import _sd4_commitment_values


def test_sd4_commitment_uses_original_protheus_balance_fields():
    payload = _sd4_commitment_values(
        filial="04",
        op="01596101001",
        produto="575-0863",
        produto_pai="730-0863",
        local="10",
        quantidade=500,
        data="20260729",
        estrutura="010",
    )

    assert payload["d4_filial"] == "04"
    assert payload["d4_cod"] == "575-0863"
    assert payload["d4_local"] == "10"
    assert payload["d4_op"] == "01596101001"
    assert payload["d4_data"] == "20260729"
    assert payload["d4_qsusp"] == 0
    assert payload["d4_qtdeori"] == 500
    assert payload["d4_quant"] == 500
    assert payload["d4_sldemp"] == 0
    assert payload["d4_sldemp2"] == 0
    assert payload["d4_qtneces"] == 0
    assert payload["d4_produto"] == "730-0863"
    assert payload["d4_roteiro"] == "01"
    assert payload["d4_trt"] == "010"
    assert payload["r_e_c_d_e_l_"] == 0
    assert payload["d_e_l_e_t_"] == ""
