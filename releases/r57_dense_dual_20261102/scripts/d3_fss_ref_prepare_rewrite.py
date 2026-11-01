"""Exact, reversible FSS reference predicate preparation in existing RAM wait."""

ANCHOR = 'wire background_reference_ok=context_ref ? context_reference_ok : left_dark>=ref_min && right_dark+dark_word>=ref_min;'
PREPARED = '''// Prepare the five possible reference predicates before the new RAM word.
// WORD_DARK is exactly 9 bits: retain the original comparison's modulo-512
// addition. Accumulation and 32-bit diagnostic expressions stay unchanged.
reg [4:0] reference_bad_choices;
genvar ref_choice;
generate for(ref_choice=0;ref_choice<5;ref_choice=ref_choice+1)begin : prepare_reference
 localparam [8:0] WORD_DARK=ref_choice;
 always @(posedge clk)if(phase==REF_WAIT)
  reference_bad_choices[ref_choice]<=left_dark<ref_min || right_dark+WORD_DARK<ref_min;
end endgenerate
wire prepared_reference_bad=reference_bad_choices[dark_word];
wire background_reference_ok=context_ref ? context_reference_ok : !prepared_reference_bad;'''
ORIGINAL_REASON = "else if(reason_bank[ref_index]!=4'hf)reason_bank[ref_index][3]<=left_dark<ref_min || right_dark+dark_word<ref_min;"
PREPARED_REASON = "else if(reason_bank[ref_index]!=4'hf)reason_bank[ref_index][3]<=prepared_reference_bad;"


def apply(text):
    assert text.count(ANCHOR) == text.count(ORIGINAL_REASON) == 1
    return text.replace(ANCHOR, PREPARED, 1).replace(ORIGINAL_REASON, PREPARED_REASON, 1)


def restore(text):
    assert text.count(PREPARED) == text.count(PREPARED_REASON) == 1
    return text.replace(PREPARED, ANCHOR, 1).replace(PREPARED_REASON, ORIGINAL_REASON, 1)
