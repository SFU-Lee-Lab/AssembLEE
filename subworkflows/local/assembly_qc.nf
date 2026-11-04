// import modules
include { QUAST } from '../../modules/nf-core/quast/main.nf'
include { QUAST as QUAST_ASM } from '../../modules/local/quast/main.nf'
include { CHECKM_TAXONOMYWF } from '../../modules/local/checkm/taxonomy_wf/main.nf'
include { GUNC_RUN } from '../../modules/nf-core/gunc/run/main.nf'
include { SOURMASH_SKETCH } from '../../modules/nf-core/sourmash/sketch/main.nf'
include { SOURMASH_GATHER } from '../../modules/nf-core/sourmash/gather/main.nf'

workflow ASSEMBLY_QC {
    take: 
        assembly
        reads
        species_id
    main:
        
        // QUAST on polished assembly
        ch_quast_input = assembly.join(reads, remainder: true)
        ch_quast_input
        .branch {
            with_reads: it[-1] != null
            without_reads: true
        }
        .set { ch_quast_branch }
        
        QUAST(
            ch_quast_branch.with_reads,
            [ [], [] ],
            [ [], [] ]
        )

        ch_assembly_only = ch_quast_branch.without_reads.map { meta, asm, reads ->
            return [ meta, asm]
        }
        QUAST_ASM(
            ch_assembly_only,
            [ [], [] ],
            [ [], [] ]
        )  
        
        // checkm
        ch_checkm_input = assembly.join(species_id)
        CHECKM_TAXONOMYWF(
            ch_checkm_input,
            ".fa.gz", // fasta extension
        )

        // gunc
        ch_gunc_db = Channel.fromPath(
            params.gunc_db, 
            checkIfExists: true,
            type: 'dir'
        )
        GUNC_RUN(
            assembly,
            ch_gunc_db.first() // db path
        )
        
        // sourmash
        SOURMASH_SKETCH(
            assembly
        )
        ch_sourmash_db = Channel.fromPath(
            params.sourmash_db, 
            checkIfExists: true,
            type: 'dir'
        )
        SOURMASH_GATHER(
            SOURMASH_SKETCH.out.signatures,
            ch_sourmash_db.first(),
            false,
            false,
            false,
            false
        )
}