include { RAXMLNG_SEARCH        } from '../../../modules/nf-core/raxmlng/search/main'
include { SATIVAEPANG_REFERENCE } from '../../../modules/nf-core/sativaepang/reference/main'
include { SATIVAEPANG_LOOTASKS  } from '../../../modules/nf-core/sativaepang/lootasks/main'
include { SATIVAEPANG_LOOPLACE  } from '../../../modules/nf-core/sativaepang/looplace/main'
include { SATIVAEPANG_LOOSCORE  } from '../../../modules/nf-core/sativaepang/looscore/main'

workflow FASTA_TAX_DETECTMISLABELS_SATIVAEPANG {

    take:
    ch_alignment_taxonomy // channel: [ val(meta), path(alignment), path(taxonomy), val(taxcode), val(raxmlng_model) ]

    main:
    RAXMLNG_SEARCH(
        ch_alignment_taxonomy.map { meta, alignment, taxonomy, taxcode, raxmlng_model -> [ meta, alignment, raxmlng_model ] },
        [],
        [],
        [],
        []
    )

    // RAXMLNG_SEARCH's tree/model become sativaepang/reference's -reftree/-refmodel:
    // joined by meta.id, then split back into three per-invocation projections of the
    // *same* joined channel, since sativaepang/reference's own reftree/refmodel inputs
    // carry no meta and would otherwise pair with the main channel by emission order
    // alone (unsafe once more than one sample runs concurrently -- see the module's own
    // input contract).
    ch_reference_input = ch_alignment_taxonomy
        .map { meta, alignment, taxonomy, taxcode, raxmlng_model -> [ meta, alignment, taxonomy, taxcode ] }
        .join(RAXMLNG_SEARCH.out.phylogeny)
        .join(RAXMLNG_SEARCH.out.best_model)
    // ch_reference_input: [ meta, alignment, taxonomy, taxcode, reftree, refmodel ]

    SATIVAEPANG_REFERENCE(
        ch_reference_input.map { meta, alignment, taxonomy, taxcode, reftree, refmodel -> [ meta, alignment, taxonomy, taxcode ] },
        ch_reference_input.map { meta, alignment, taxonomy, taxcode, reftree, refmodel -> reftree },
        ch_reference_input.map { meta, alignment, taxonomy, taxcode, reftree, refmodel -> refmodel }
    )

    SATIVAEPANG_LOOTASKS(
        SATIVAEPANG_REFERENCE.out.refjson.join(SATIVAEPANG_REFERENCE.out.model)
    )

    SATIVAEPANG_LOOPLACE(
        SATIVAEPANG_LOOTASKS.out.taskdir
    )

    SATIVAEPANG_LOOSCORE(
        SATIVAEPANG_REFERENCE.out.refjson.join(SATIVAEPANG_LOOPLACE.out.taskdir)
    )

    emit:
    mis       = SATIVAEPANG_LOOSCORE.out.mis     // channel: [ val(meta), path(mis) ]
    phylogeny = RAXMLNG_SEARCH.out.phylogeny     // channel: [ val(meta), path(tree) ]
}
