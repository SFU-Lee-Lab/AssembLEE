process MINIPOLISH {
    tag "${meta.id}"
    label 'process_medium'

    conda "${moduleDir}/environment.yml"
    container "${workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/minipolish:0.2.1--pyhdfd78af_0':
        'quay.io/biocontainers/minipolish:0.2.1--pyhdfd78af_0' }"

    input:
    // reads should be concatenated into single fasta or fastq
    // assembly should be gfa
    tuple val(meta), path(reads), path(assembly)

    output:
    tuple val(meta), path("*.gfa.gz"), emit: assembly
    tuple val("${task.process}"), val('minipolish'), emit: versions_minipolish

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    minipolish \\
        -t ${task.cpus} \\
        ${args} \\
        ${reads} \\
        ${assembly} > \\
        ${prefix}_polish.gfa

    gzip -c ${prefix}_polish.gfa > ${prefix}_polish.gfa.gz

    # cat <<-END_VERSIONS > versions.yml
    # "${task.process}":
    #     minipolish: \$(samtools --version |& sed '1!d ; s/samtools //')
    # END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    echo stub | gzip -c > ${prefix}.gfa.gz

    # cat <<-END_VERSIONS > versions.yml
    #"${task.process}":
    #    minipolish: \$(samtools --version |& sed '1!d ; s/samtools //')
    # END_VERSIONS
    """
}
