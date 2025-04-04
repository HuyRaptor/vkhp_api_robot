*** Settings ***
Documentation     Advanced Test Suite for Product Operations in vKho API
...               Includes complex scenarios like bulk operations, dependencies, concurrency, pagination, and edge cases
Library           RequestsLibrary
Library           Collections
Library           OperatingSystem
Library           String
Library           DateTime
Library           BuiltIn
Resource          ../../Variables/variables.robot

*** Keywords ***
Setup API Session
    [Documentation]     Create API session and authenticate
    Create Session      vkho             ${BASE_URL}      verify=True    disable_warnings=True
    
    # Prepare login request
    ${headers}=         Create Dictionary    Content-Type=application/json
    ${body}=            Create Dictionary    username=${USERNAME}    password=${PASSWORD}
    
    # Send login request
    ${response}=        POST On Session
    ...                 vkho
    ...                 /auth/login
    ...                 json=${body}
    ...                 headers=${headers}
    ...                 expected_status=201
    
    # Process response
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    Dictionary Should Contain Key        ${json}    access_token
    ...    msg=Authentication failed: Response did not contain access_token
    
    # Save token for subsequent tests
    ${token}=           Set Variable     Bearer ${json}[access_token]
    Set Global Variable  ${AUTH_TOKEN}    ${token}
    
    # Create results directory if it doesn't exist
    Create Directory    ${RESULTS_DIR}

Generate Unique Product Data
    [Documentation]     Generate unique data for product tests
    [Arguments]         ${custom_name}=Test Product    ${supplier_id}=${EMPTY}
    
    ${timestamp}=       Evaluate         int(time.time())    time
    ${product_sku}=     Set Variable     SKU${timestamp}
    
    # Base product data
    ${product_data}=    Create Dictionary
    ...                 name=${custom_name} ${timestamp}
    ...                 sku=${product_sku}
    ...                 barcode=BAR${timestamp}
    ...                 description=Description for ${custom_name} ${timestamp}
    ...                 price=99.99
    ...                 unit=Piece
    ...                 warehouseId=${WAREHOUSE_ID}
    ...                 productCategoryId=${PRODUCT_CATEGORY_ID}
    
    # Add optional supplier dependency
    Run Keyword If      "${supplier_id}" != "${EMPTY}"    Set To Dictionary    ${product_data}    supplierId=${supplier_id}
    
    RETURN            ${product_data}

Create Product
    [Documentation]     Create a new product and return its ID
    [Arguments]         ${product_data}
    
    # Validate required parameters
    Dictionary Should Contain Key    ${product_data}    name
    ...    msg=Missing required parameter: name
    Dictionary Should Contain Key    ${product_data}    sku
    ...    msg=Missing required parameter: sku
    Dictionary Should Contain Key    ${product_data}    warehouseId
    ...    msg=Missing required parameter: warehouseId
    Dictionary Should Contain Key    ${product_data}    productCategoryId
    ...    msg=Missing required parameter: productCategoryId
    
    # Prepare request
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    # Send create product request
    ${response}=        POST On Session
    ...                 vkho
    ...                 /products/create
    ...                 json=${product_data}
    ...                 headers=${headers}
    ...                 expected_status=201
    
    # Process response
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    Should Not Be Empty    ${json}
    ...    msg=Create product response was empty
    Dictionary Should Contain Key        ${json}    id
    ...    msg=Create product response missing ID field
    
    # Return product ID and full response
    ${product_id}=      Convert To String    ${json}[id]
    RETURN            ${product_id}    ${json}

Get Product By ID
    [Documentation]     Retrieve a specific product by ID
    [Arguments]         ${product_id}
    
    # Validate parameters
    Should Not Be Empty    ${product_id}
    ...    msg=Product ID cannot be empty
    
    # Prepare request
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    # Send get product request
    ${response}=        GET On Session
    ...                 vkho
    ...                 /products/get-one/${product_id}
    ...                 headers=${headers}
    ...                 expected_status=200
    
    # Process response
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    Should Not Be Empty    ${json}
    ...    msg=Get product response was empty
    Dictionary Should Contain Key        ${json}    id
    ...    msg=Get product response missing ID field
    
    RETURN            ${json}

Update Product
    [Documentation]     Update an existing product
    [Arguments]         ${product_id}    ${update_data}
    
    # Validate parameters
    Should Not Be Empty    ${product_id}
    ...    msg=Product ID cannot be empty
    Dictionary Should Contain Key    ${update_data}    id
    ...    msg=Update data must contain id field
    Should Be Equal     ${update_data}[id]    ${product_id}
    ...    msg=Update data ID must match product_id parameter
    
    # Ensure minimum required fields are present
    Dictionary Should Contain Key    ${update_data}    name
    ...    msg=Update data missing required field: name
    Dictionary Should Contain Key    ${update_data}    sku
    ...    msg=Update data missing required field: sku
    Dictionary Should Contain Key    ${update_data}    warehouseId
    ...    msg=Update data missing required field: warehouseId
    Dictionary Should Contain Key    ${update_data}    productCategoryId
    ...    msg=Update data missing required field: productCategoryId
    
    # Prepare request
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    # Send update product request
    ${response}=        PUT On Session
    ...                 vkho
    ...                 /products/update
    ...                 json=${update_data}
    ...                 headers=${headers}
    ...                 expected_status=200
    
    # Process response
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    Should Not Be Empty    ${json}
    ...    msg=Update product response was empty
    Dictionary Should Contain Key        ${json}    id
    ...    msg=Update product response missing ID field
    
    RETURN            ${json}

Delete Product
    [Documentation]     Delete a product from the system
    [Arguments]         ${product_id}
    
    # Validate parameters
    Should Not Be Empty    ${product_id}
    ...    msg=Product ID cannot be empty
    
    # Prepare request
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    # Send delete product request
    ${response}=        DELETE On Session
    ...                 vkho
    ...                 /products/delete/${product_id}
    ...                 headers=${headers}
    ...                 expected_status=200
    
    # Return deletion status
    RETURN            ${TRUE}

Get All Products
    [Documentation]     Retrieve all products with filtering, pagination, and sorting
    [Arguments]         ${filter_params}=${EMPTY}    ${page}=${EMPTY}    ${limit}=${EMPTY}    ${sort}=${EMPTY}
    
    # Prepare request
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    # Create params dictionary
    ${params}=          Create Dictionary
    Run Keyword If      "${filter_params}" != "${EMPTY}"    Set To Dictionary    ${params}    &{filter_params}
    Run Keyword If      "${page}" != "${EMPTY}"             Set To Dictionary    ${params}    page=${page}
    Run Keyword If      "${limit}" != "${EMPTY}"            Set To Dictionary    ${params}    limit=${limit}
    Run Keyword If      "${sort}" != "${EMPTY}"             Set To Dictionary    ${params}    sort=${sort}
    
    # Send get all products request
    ${response}=        GET On Session
    ...                 vkho
    ...                 /products/get-all
    ...                 params=${params}
    ...                 headers=${headers}
    ...                 expected_status=200
    
    # Process response
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    Should Not Be Empty    ${json}
    ...    msg=Get all products response was empty
    
    RETURN            ${json}

Create Supplier
    [Documentation]     Create a supplier for product dependency
    ${timestamp}=       Evaluate         int(time.time())    time
    ${supplier_data}=   Create Dictionary
    ...                 name=Supplier ${timestamp}
    ...                 code=SUP${timestamp}
    ...                 phoneNumber=800555${timestamp}
    ...                 email=supplier_${timestamp}@example.com
    ...                 address=123 Supplier Street
    
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    ${response}=        POST On Session
    ...                 vkho
    ...                 /suppliers/create
    ...                 json=${supplier_data}
    ...                 headers=${headers}
    ...                 expected_status=201
    
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    ${supplier_id}=     Convert To String    ${json}[id]
    RETURN            ${supplier_id}

Bulk Create Products
    [Documentation]     Create multiple products in bulk with validation
    [Arguments]         ${count}=5
    
    ${product_ids}=     Create List
    FOR    ${i}    IN RANGE    ${count}
        ${product_data}=    Generate Unique Product Data    custom_name=Bulk Product ${i}
        ${product_id}    ${response}=    Create Product    ${product_data}
        Append To List      ${product_ids}    ${product_id}
    END
    RETURN            ${product_ids}

Assert Product Details
    [Documentation]     Verify product details match expected values
    [Arguments]         ${product}    ${expected_data}
    
    FOR    ${key}    IN    @{expected_data.keys()}
        Run Keyword If    "${key}" in ${product}
        ...               Should Be Equal    ${product}[${key}]    ${expected_data}[${key}]
        ...               msg=Product ${key} value '${product}[${key}]' does not match expected '${expected_data}[${key}]'
    END

Create Test Product
    [Documentation]     Creates a test product if one doesn't exist
    ${product_data}=    Generate Unique Product Data
    ${product_id}    ${response}=    Create Product    ${product_data}
    Set Global Variable  ${TEST_PRODUCT_ID}      ${product_id}
    Set Global Variable  ${TEST_PRODUCT_SKU}     ${response}[sku]
    Set Global Variable  ${TEST_PRODUCT_DATA}    ${product_data}

*** Test Cases ***
01 - Setup Test Environment
    [Documentation]     Setup API session for complex product tests
    [Tags]              setup
    Setup API Session
    Log                 Successfully authenticated with token: ${AUTH_TOKEN}

02 - Bulk Product Creation With Validation Test
    [Documentation]     Test creating multiple products in bulk with validation
    [Tags]              create    bulk    positive
    
    ${bulk_ids}=        Bulk Create Products    count=5
    Should Not Be Empty    ${bulk_ids}
    ...    msg=Failed to create bulk products: No IDs returned
    Should Be Equal As Integers    ${bulk_ids.__len__()}    5
    ...    msg=Expected 5 products, but created ${bulk_ids.__len__()}
    
    # Verify each product exists
    FOR    ${id}    IN    @{bulk_ids}
        ${product}=     Get Product By ID    ${id}
        Should Not Be Empty    ${product}
        ...    msg=Product ${id} from bulk creation not found
    END
    
    Set Global Variable  ${BULK_PRODUCT_IDS}    ${bulk_ids}
    Log                 Successfully created and validated ${bulk_ids.__len__()} products: ${bulk_ids}

03 - Create Product With Duplicate SKU Test
    [Documentation]     Test creating a product with a duplicate SKU
    [Tags]              create    negative
    
    # Create first product
    ${product_data}=    Generate Unique Product Data    custom_name=Duplicate Product
    ${product_id}    ${response}=    Create Product    ${product_data}
    
    # Attempt to create second product with same SKU
    ${duplicate_data}=  Create Dictionary    &{product_data}
    Set To Dictionary   ${duplicate_data}    name=Duplicate Product 2
    
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    ${response}=        POST On Session
    ...                 vkho
    ...                 /products/create
    ...                 json=${duplicate_data}
    ...                 headers=${headers}
    ...                 expected_status=any
    
    Should Not Equal As Integers    ${response.status_code}    201
    ...    msg=API allowed creation of product with duplicate SKU
    Log                 Successfully verified duplicate SKU rejection: ${response.text}

04 - Product With Supplier Dependency Test
    [Documentation]     Test creating and retrieving a product with a supplier dependency
    [Tags]              create    retrieve    dependency    positive
    
    # Create supplier
    ${supplier_id}=     Create Supplier
    Set Global Variable  ${TEST_SUPPLIER_ID}    ${supplier_id}
    
    # Create product with supplier
    ${product_data}=    Generate Unique Product Data    custom_name=Dependency Product    supplier_id=${supplier_id}
    ${product_id}    ${response}=    Create Product    ${product_data}
    
    # Retrieve and verify
    ${product}=         Get Product By ID    ${product_id}
    Assert Product Details    ${product}    ${product_data}
    Should Be Equal     ${product}[supplierId]    ${supplier_id}
    ...    msg=Product supplierId does not match expected
    
    Log                 Successfully created and retrieved product ${product_id} with supplier ${supplier_id}

05 - Concurrent Product Price Updates Test
    [Documentation]     Test concurrent price updates to a product
    [Tags]              update    concurrent    positive
    
    # Create product
    ${product_data}=    Generate Unique Product Data    custom_name=Concurrent Product
    ${product_id}    ${response}=    Create Product    ${product_data}
    
    # First update: Price to 149.99
    ${update_data_1}=   Create Dictionary
    ...                 id=${product_id}
    ...                 name=${product_data}[name]
    ...                 sku=${product_data}[sku]
    ...                 barcode=${product_data}[barcode]
    ...                 description=${product_data}[description]
    ...                 price=149.99
    ...                 unit=${product_data}[unit]
    ...                 warehouseId=${WAREHOUSE_ID}
    ...                 productCategoryId=${PRODUCT_CATEGORY_ID}
    ${updated_1}=       Update Product    ${product_id}    ${update_data_1}
    
    # Second update: Price to 199.99 (simulating concurrent change)
    ${update_data_2}=   Create Dictionary    &{update_data_1}
    Set To Dictionary   ${update_data_2}    price=199.99
    ${updated_2}=       Update Product    ${product_id}    ${update_data_2}
    
    # Verify final state
    ${final_product}=   Get Product By ID    ${product_id}
    Should Be Equal As Numbers    ${final_product}[price]    199.99
    ...    msg=Second concurrent update did not apply correctly
    
    Log                 Successfully verified concurrent price updates on product ${product_id}

06 - Pagination And Advanced Filtering Products Test
    [Documentation]     Test retrieving products with pagination and multiple filters
    [Tags]              retrieve    pagination    filter    positive
    
    # Ensure bulk products exist
    Run Keyword If      "${BULK_PRODUCT_IDS}" == "${EMPTY}"    Bulk Create Products    count=10
    
    # Filter by SKU prefix and price range, paginate (page 1, limit 3)
    ${filter_params}=   Create Dictionary
    ...                 sku=SKU
    ...                 minPrice=50
    ...                 maxPrice=150
    ${products_page_1}=    Get All Products    filter_params=${filter_params}    page=1    limit=3
    
    # Verify response structure
    ${has_data}=        Run Keyword And Return Status    Dictionary Should Contain Key    ${products_page_1}    data
    ${has_items}=       Run Keyword And Return Status    Dictionary Should Contain Key    ${products_page_1}    items
    ${has_records}=     Run Keyword And Return Status    Dictionary Should Contain Key    ${products_page_1}    records
    
    ${items}=           Set Variable    ${EMPTY}
    IF    ${has_data}
        ${items}=       Set Variable    ${products_page_1}[data]
    ELSE IF    ${has_items}
        ${items}=       Set Variable    ${products_page_1}[items]
    ELSE IF    ${has_records}
        ${items}=       Set Variable    ${products_page_1}[records]
    END
    
    Should Not Be Empty    ${items}
    ...    msg=Paginated products neuropath response was empty
    Should Be True         ${items.__len__()} <= 3
    ...    msg=Page 1 exceeded limit of 3 items: ${items.__len__()}
    
    # Verify filters applied
    FOR    ${item}    IN    @{items}
        Should Be True    "${item['sku']}".startswith("SKU")
        ...    msg=Product ${item['id']} SKU does not match filter
        Should Be True    ${item['price']} >= 50 and ${item['price']} <= 150
        ...    msg=Product ${item['id']} price ${item['price']} outside filter range
    END
    
    Log                 Successfully retrieved paginated and filtered products: ${items.__len__()} items

07 - Delete Product With Supplier Dependency Test
    [Documentation]     Test deleting a product with a supplier dependency
    [Tags]              delete    dependency    negative
    
    # Create supplier and product
    ${supplier_id}=     Create Supplier
    ${product_data}=    Generate Unique Product Data    custom_name=Delete Dependency Product    supplier_id=${supplier_id}
    ${product_id}    ${response}=    Create Product    ${product_data}
    
    # Attempt to delete product with dependency
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    ${response}=        DELETE On Session
    ...                 vkho
    ...                 /products/delete/${product_id}
    ...                 headers=${headers}
    ...                 expected_status=any
    
    # Expect failure if API enforces dependency (assumption)
    Should Not Equal As Integers    ${response.status_code}    200
    ...    msg=API allowed deletion of product with dependent supplier
    Log                 Successfully verified rejection of product deletion with supplier ${supplier_id}

08 - Edge Case - Product With Malformed Price Test
    [Documentation]     Test creating a product with a malformed price
    [Tags]              create    edge    negative
    
    ${product_data}=    Generate Unique Product Data    custom_name=Malformed Price Product
    Set To Dictionary   ${product_data}    price=invalid-price
    
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    ${response}=        POST On Session
    ...                 vkho
    ...                 /products/create
    ...                 json=${product_data}
    ...                 headers=${headers}
    ...                 expected_status=any
    
    Should Not Equal As Integers    ${response.status_code}    201
    ...    msg=API allowed creation of product with malformed price
    Log                 Successfully verified rejection of product with malformed price: ${response.text}

09 - Edge Case - Product With Maximum Length Fields Test
    [Documentation]     Test creating a product with maximum length field values
    [Tags]              create    edge    positive
    
    ${long_name}=       Set Variable    ${"A" * 255}    # Assuming 255 char limit
    ${long_sku}=        Set Variable    SKU${"X" * 50}  # Assuming 50 char limit
    
    ${product_data}=    Create Dictionary
    ...                 name=${long_name}
    ...                 sku=${long_sku}
    ...                 barcode=BAR_MAX
    ...                 description=Max length product description
    ...                 price=99.99
    ...                 unit=Piece
    ...                 warehouseId=${WAREHOUSE_ID}
    ...                 productCategoryId=${PRODUCT_CATEGORY_ID}
    
    ${product_id}    ${response}=    Create Product    ${product_data}
    Should Not Be Empty    ${product_id}
    ...    msg=Failed to create product with max length fields
    
    ${product}=         Get Product By ID    ${product_id}
    Should Be Equal     ${product}[name]    ${long_name}
    ...    msg=Created product name does not match max length input
    Should Be Equal     ${product}[sku]    ${long_sku}
    ...    msg=Created product SKU does not match max length input
    Log                 Successfully created product with maximum length fields: ${product_id}

10 - Cleanup Test Environment
    [Documentation]     Clean up resources created during complex tests
    [Tags]              cleanup
    
    # Clean up bulk products
    Run Keyword If      "${BULK_PRODUCT_IDS}" != "${EMPTY}"
    ...                 Run Keywords
    ...                 FOR    ${id}    IN    @{BULK_PRODUCT_IDS}
    ...                 Delete Product    ${id}
    ...                 END
    ...                 AND    Set Global Variable    ${BULK_PRODUCT_IDS}    ${EMPTY}
    
    # Clean up test product
    Run Keyword If      "${TEST_PRODUCT_ID}" != "${EMPTY}"
    ...                 Delete Product    ${TEST_PRODUCT_ID}
    ...                 AND    Set Global Variable    ${TEST_PRODUCT_ID}    ${EMPTY}
    
    # Clean up supplier
    Run Keyword If      "${TEST_SUPPLIER_ID}" != "${EMPTY}"
    ...                 DELETE On Session    vkho    /suppliers/delete/${TEST_SUPPLIER_ID}    headers=${headers}
    ...                 AND    Set Global Variable    ${TEST_SUPPLIER_ID}    ${EMPTY}
    
    Log                 Test environment cleaned up successfully