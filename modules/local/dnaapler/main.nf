process DNAAPLER {
    tag "${meta.id}"
    label 'process_single'

    conda "${moduleDir}/environment.yml"
    container "${workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/dnaapler:1.4.0--pyhdfd78af_0':
        'quay.io/biocontainers/dnaapler:1.4.0--pyhdfd78af_0' }"

    input:
    // assembly should be gfa
    tuple val(meta), path(assembly)

    output:
    tuple val(meta), path("*/${prefix}_reoriented.gfa.gz"), emit: gfa
    tuple val(meta), path("*/${prefix}_all_reorientation_summary.tsv"), emit: tsv
    tuple val(meta), path("*/${prefix}_MMseqs2_output.txt"), emit: txt, optional: true
    tuple val(meta), path("*/${prefix}.log"), emit: log
    tuple val(meta), path("*/${prefix}_mmseqs.err"), emit: mmseqs_err, optional: true
    tuple val(meta), path("*/${prefix}_mmseqs.out"), emit: mmseqs_out, optional: true
    tuple val("${task.process}"), val('dnaapler'), emit: versions_dnaapler

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    prefix = task.ext.prefix ?: "${meta.id}"
    """
    dnaapler \\
        all \\
        -i ${assembly} \\
        -o ${prefix} \\
        ${args} \\
        -t ${task.cpus} \\
        -p ${prefix}
        
    gzip -c ${prefix}/${prefix}_reoriented.gfa > ${prefix}/${prefix}_reoriented.gfa.gz
    mv ${prefix}/*.log ${prefix}/${prefix}.log
    # mv ${prefix}/logs/*.err logs/${prefix}_mmseqs.err
    # mv ${prefix}/logs/*.out logs/${prefix}_mmseqs.out

    # cat <<-END_VERSIONS > versions.yml
    # "${task.process}":
    #     dnaapler: \$(samtools --version |& sed '1!d ; s/samtools //')
    # END_VERSIONS
    """

    stub:
    prefix = task.ext.prefix ?: "${meta.id}"
    """
    mkdir -p logs
    echo stub | gzip -c > ${prefix}_reoriented.gfa.gz
    echo stub > ${prefix}_all_reorientation_summary.tsv
    echo stub > ${prefix}_MMseqs2_output.txt
    echo stub > ${prefix}.log
    echo stub > logs/${prefix}_mmseqs.err
    echo stub > logs/${prefix}_mmseqs.out

    # cat <<-END_VERSIONS > versions.yml
    # "${task.process}":
    #     dnaapler: \$(samtools --version |& sed '1!d ; s/samtools //')
    # END_VERSIONS
    """
}
