require 'httparty'
require 'nokogiri'

module PubChemAPI
  # Custom exception class for API errors
  class APIError < StandardError
    attr_reader :code

    def initialize(message, code = nil)
      super(message)
      @code = code
    end
  end

  # Base class for API responses
  class APIResponse
    def initialize(data)
      @data = data
    end
  end

  class CompoundRecord < APIResponse
    attr_reader :cid, :iupac_name, :molecular_formula, :molecular_weight, :canonical_smiles, :inchi, :inchi_key

    def initialize(data)
      super(data)
      compound = data['PC_Compounds'].first
      @cid = compound['id']['id']['cid']

      # Extract properties from the 'props' array
      props = compound['props']
      @iupac_name = extract_prop(props, 'IUPAC Name')
      @molecular_formula = extract_prop(props, 'Molecular Formula')
      @molecular_weight = extract_prop(props, 'Molecular Weight')
      @canonical_smiles = extract_prop(props, 'SMILES', 'Canonical')
      @inchi = extract_prop(props, 'InChI', 'Standard')
      @inchi_key = extract_prop(props, 'InChIKey', 'Standard')
    end

    private

    def extract_prop(props, label, name = nil)
      prop = props.find do |p|
        p['urn']['label'] == label && (name.nil? || p['urn']['name'] == name)
      end
      prop ? prop['value'].values.first : nil
    end
  end

  class SubstanceRecord < APIResponse
    attr_reader :sid, :synonyms, :source_name

    def initialize(data)
      super(data)
      substance = data['PC_Substances'].first
      @sid = substance['sid']['id']
      @synonyms = substance['synonyms']
      @source_name = substance['source']['db']['name']
    end
  end

  class AssayRecord < APIResponse
    attr_reader :aid, :name, :description

    def initialize(data)
      super(data)
      assay_container = data['PC_AssayContainer'].first
      assay = assay_container['assay']
      descr = assay['descr']
      @aid = descr['aid']['id']
      @name = descr['name']
      @description = descr['description']
    end
  end

  class GeneSummary < APIResponse
    attr_reader :gene_id, :symbol, :name, :taxonomy_id, :description

    def initialize(data)
      super(data)
      gene = data['InformationList']['Information'].first
      @gene_id = gene['GeneID']
      @symbol = gene['Symbol']
      @name = gene['Name']
      @taxonomy_id = gene['TaxID']
      @description = gene['Description']
    end
  end

  class TaxonomySummary < APIResponse
    attr_reader :taxonomy_id, :scientific_name, :common_name, :rank, :synonyms

    def initialize(data)
      super(data)
      taxon = data['TaxaInfo'].first
      @taxonomy_id = taxon['TaxId']
      @scientific_name = taxon['ScientificName']
      @common_name = taxon['OtherNames']['CommonName']
      @rank = taxon['Rank']
      @synonyms = taxon['OtherNames']['Synonym']
    end
  end

  class PathwaySummary < APIResponse
    attr_reader :pathway_accession, :source_name, :name, :category, :description, :taxonomy_id

    def initialize(data)
      super(data)
      pathway = data['Pathway'].first
      @pathway_accession = pathway['PathwayId']
      @source_name = pathway['SourceName']
      @name = pathway['Name']
      @category = pathway['Category']
      @description = pathway['Description']
      @taxonomy_id = pathway['TaxId']
    end
  end

  class ProteinSummary < APIResponse
    attr_reader :accession, :name, :taxonomy_id, :synonyms

    def initialize(data)
      super(data)
      protein = data['InformationList']['Information'].first
      @accession = protein['Accession']
      @name = protein['Title']
      @taxonomy_id = protein['TaxId']
      @synonyms = protein['Synonym']
    end
  end

  class Client
    include HTTParty
    base_uri 'https://pubchem.ncbi.nlm.nih.gov/rest/pug'

    # Constants for allowed values
    COMPOUND_OPERATIONS = %w[record property synonyms sids aids classification description conformers]
    SUBSTANCE_OPERATIONS = %w[record synonyms cids aids classification description]
    ASSAY_OPERATIONS = %w[record concise description summary doseresponse targets]
    OUTPUT_FORMATS = %w[XML JSON JSONP ASNT ASNB SDF CSV TXT PNG]
    OUTPUT_FORMATS_SIMPLE = %w[XML JSON]
    SEARCH_TYPES = %w[fastsubstructure fastsuperstructure fastsimilarity_2d fastidentity fastformula]
    NAMESPACES = %w[smiles inchi sdf cid]
    ID_TYPES = %w[cid sid aid patent geneid protein taxonomyid pathwayid cellid]
    TARGET_TYPES = %w[ProteinGI ProteinName GeneID GeneSymbol]
    DEFAULT_OUTPUT = 'JSON'

    # Retrieve compound data by CID
    def get_compound_by_cid(cid, operation, output = DEFAULT_OUTPUT, options = {})
      validate_operation(operation, COMPOUND_OPERATIONS)
      validate_output_format(output, OUTPUT_FORMATS)
      path = "/compound/cid/#{cid}/#{operation}/#{output}"
      response = self.class.get(path, query: options)
      parse_response(response, output, 'CompoundRecord')
    end

    # Retrieve compound data by name
    def get_compound_by_name(name, operation, output = DEFAULT_OUTPUT, options = {})
      validate_operation(operation, COMPOUND_OPERATIONS)
      validate_output_format(output, OUTPUT_FORMATS)
      name_encoded = CGI.escape(name)
      path = "/compound/name/#{name_encoded}/#{operation}/#{output}"
      response = self.class.get(path, query: options)
      parse_response(response, output, 'CompoundRecord')
    end

    # Retrieve substance data by SID
    def get_substance_by_sid(sid, operation, output = DEFAULT_OUTPUT, options = {})
      validate_operation(operation, SUBSTANCE_OPERATIONS)
      validate_output_format(output, OUTPUT_FORMATS)
      path = "/substance/sid/#{sid}/#{operation}/#{output}"
      response = self.class.get(path, query: options)
      parse_response(response, output, 'SubstanceRecord')
    end

    # Retrieve assay data by AID
    def get_assay_by_aid(aid, operation, output = DEFAULT_OUTPUT, options = {})
      validate_operation(operation, ASSAY_OPERATIONS)
      validate_output_format(output, OUTPUT_FORMATS)
      path = "/assay/aid/#{aid}/#{operation}/#{output}"
      response = self.class.get(path, query: options)
      parse_response(response, output, 'AssayRecord')
    end

    # Retrieve gene summary by GeneID
    def get_gene_summary_by_geneid(geneid, output = DEFAULT_OUTPUT, options = {})
      validate_output_format(output, OUTPUT_FORMATS_SIMPLE)
      path = "/gene/geneid/#{geneid}/summary/#{output}"
      response = self.class.get(path, query: options)
      parse_response(response, output, 'GeneSummary')
    end

    # Retrieve taxonomy summary by TaxonomyID
    def get_taxonomy_summary_by_taxid(taxid, output = DEFAULT_OUTPUT, options = {})
      validate_output_format(output, OUTPUT_FORMATS_SIMPLE)
      path = "/taxonomy/taxid/#{taxid}/summary/#{output}"
      response = self.class.get(path, query: options)
      parse_response(response, output, 'TaxonomySummary')
    end

    # Retrieve pathway summary by pathway accession
    def get_pathway_summary_by_pwacc(pwacc, output = DEFAULT_OUTPUT, options = {})
      validate_output_format(output, OUTPUT_FORMATS_SIMPLE)
      pwacc_encoded = CGI.escape(pwacc)
      path = "/pathway/pwacc/#{pwacc_encoded}/summary/#{output}"
      response = self.class.get(path, query: options)
      parse_response(response, output, 'PathwaySummary')
    end

    # Retrieve assay dose-response data
    def get_assay_doseresponse(aid, output = DEFAULT_OUTPUT, options = {})
      validate_output_format(output, OUTPUT_FORMATS)
      path = "/assay/aid/#{aid}/doseresponse/#{output}"
      response = self.class.get(path, query: options)
      parse_response(response, output)
    end

    # Retrieve assay targets by target type
    def get_assay_targets(aid, target_type, output = DEFAULT_OUTPUT, options = {})
      validate_value(target_type, TARGET_TYPES, 'target type')
      validate_output_format(output, OUTPUT_FORMATS)
      path = "/assay/aid/#{aid}/targets/#{target_type}/#{output}"
      response = self.class.get(path, query: options)
      parse_response(response, output)
    end

    # Retrieve gene summary by synonym
    def get_gene_summary_by_synonym(synonym, output = DEFAULT_OUTPUT, options = {})
      validate_output_format(output, OUTPUT_FORMATS_SIMPLE)
      synonym_encoded = CGI.escape(synonym)
      path = "/gene/synonym/#{synonym_encoded}/summary/#{output}"
      response = self.class.get(path, query: options)
      parse_response(response, output, 'GeneSummary')
    end

    # Retrieve protein summary by synonym
    def get_protein_summary_by_synonym(synonym, output = DEFAULT_OUTPUT, options = {})
      validate_output_format(output, OUTPUT_FORMATS_SIMPLE)
      synonym_encoded = CGI.escape(synonym)
      path = "/protein/synonym/#{synonym_encoded}/summary/#{output}"
      response = self.class.get(path, query: options)
      parse_response(response, output, 'ProteinSummary')
    end

    # Retrieve compound conformers by CID
    def get_compound_conformers(cid, output = DEFAULT_OUTPUT, options = {})
      validate_output_format(output, OUTPUT_FORMATS)
      path = "/compound/cid/#{cid}/conformers/#{output}"
      response = self.class.get(path, query: options)
      parse_response(response, output)
    end

    # Search within a previous result using cache key
    def compound_fastsubstructure_search(smiles, cachekey, output = DEFAULT_OUTPUT, options = {})
      validate_output_format(output, OUTPUT_FORMATS)
      smiles_encoded = CGI.escape(smiles)
      path = "/compound/fastsubstructure/smiles/#{smiles_encoded}/cids/#{output}"
      options = options.merge('cachekey' => cachekey)
      response = self.class.get(path, query: options)
      parse_response(response, output)
    end

    # Retrieve classification nodes as cache key
    def get_classification_nodes(hnid, idtype, list_return, output = DEFAULT_OUTPUT, options = {})
      validate_value(idtype, ID_TYPES, 'ID type')
      validate_output_format(output, OUTPUT_FORMATS_SIMPLE)
      path = "/classification/hnid/#{hnid}/#{idtype}/#{output}"
      options = options.merge('list_return' => list_return)
      response = self.class.get(path, query: options)
      parse_response(response, output)
    end

    # Retrieve compounds by listkey with pagination
    def get_compounds_by_listkey(listkey, output = DEFAULT_OUTPUT, options = {})
      validate_output_format(output, OUTPUT_FORMATS)
      path = "/compound/listkey/#{listkey}/cids/#{output}"
      response = self.class.get(path, query: options)
      parse_response(response, output)
    end

    # Compound structure search operations
    def compound_structure_search(search_type, namespace, identifier, output = DEFAULT_OUTPUT, options = {})
      validate_value(search_type, SEARCH_TYPES, 'search type')
      validate_value(namespace, NAMESPACES, 'namespace')
      validate_output_format(output, OUTPUT_FORMATS)
      identifier_encoded = CGI.escape(identifier)
      path = "/compound/#{search_type}/#{namespace}/#{identifier_encoded}/cids/#{output}"
      response = self.class.get(path, query: options)
      parse_response(response, output)
    end

    private

    # Validate operation
    def validate_operation(operation, allowed_operations)
      unless allowed_operations.include?(operation)
        raise ArgumentError, "Invalid operation: #{operation}. Allowed operations: #{allowed_operations.join(', ')}"
      end
    end

    # Validate output format
    def validate_output_format(output, allowed_formats)
      unless allowed_formats.include?(output)
        raise ArgumentError, "Invalid output format: #{output}. Allowed formats: #{allowed_formats.join(', ')}"
      end
    end

    # Validate value against allowed values
    def validate_value(value, allowed_values, name)
      unless allowed_values.include?(value)
        raise ArgumentError, "Invalid #{name}: #{value}. Allowed values: #{allowed_values.join(', ')}"
      end
    end

    # Parse API response and map to Ruby objects
    def parse_response(response, output_format, schema_class = nil)
      if response.success?
        if output_format == 'JSON'
          data = response.parsed_response
          if schema_class
            klass = PubChemAPI.const_get(schema_class)
            klass.new(data)
          else
            data
          end
        elsif output_format == 'XML'
          doc = Nokogiri::XML(response.body)
          doc.remove_namespaces!
          if schema_class
            parse_xml_to_object(doc, schema_class)
          else
            doc
          end
        else
          response.body
        end
      else
        handle_error_response(response)
      end
    end

    # Handle error responses
    def handle_error_response(response)
      if response.headers['Content-Type'] && response.headers['Content-Type'].include?('application/json')
        error_info = response.parsed_response
        message = error_info['Fault']['Message'] rescue 'Unknown error'
        raise APIError.new(message, response.code)
      else
        raise APIError.new("HTTP Error #{response.code}: #{response.message}", response.code)
      end
    end

    # Parse XML to Ruby object
    def parse_xml_to_object(doc, schema_class)
      # TODO: For now, just return the raw Nokogiri document
      doc
    end
  end
end
