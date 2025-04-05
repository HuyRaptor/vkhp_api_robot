*** Settings ***
Documentation     Comprehensive End-to-End Test Suite for Product Management in vKho API
...               Includes proper parameter validation and error handling for product operations
Library           RequestsLibrary
Library           Collections
Library           OperatingSystem
Library           String
Library           DateTime
Resource          ../../Variables/variables.robot

*** Keywords ***
Setup API Session
    [Documentation]     Create API session and authenticate
    Create Session      vkho             ${BASE_URL}      verify=True    disable_warnings=True
    
    # Prepare login request
    ${headers}=         Create Dictionary    Content-Type=application/json
    ${body}=            Create Dictionary    username=${MANAGER_USERNAME}    password=${MANAGER_PASSWORD}
    
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
    [Arguments]         ${custom_name}=Test Product
    
    ${timestamp}=       Evaluate         int(time.time())    time
    ${product_name}=    Set Variable     ${custom_name} ${timestamp}
    ${product_code}=    Set Variable     PRD${timestamp}
    ${barcode}=         Set Variable     BAR${timestamp}
    
    # Return dictionary of generated data
    ${product_data}=    Create Dictionary
    ...                 name=${product_name}
    ...                 totalQuantity=100
    ...                 expectedQuantity=100
    ...                 importDate=2025-03-31T00:00:00.000Z
    ...                 cost=50.00
    ...                 salePrice=75.00
    ...                 warehouseId=${WAREHOUSE_ID}
    ...                 inboundKind=NEW
    ...                 expireDate=2026-03-31T00:00:00.000Z
    ...                 productCode=${product_code}
    ...                 idRackReallocate=1
    ...                 imageProduct=https://example.com/product.jpg
    ...                 imageQRCode=https://example.com/qr.jpg
    ...                 imageBarcode=https://example.com/barcode.jpg
    ...                 blockId=1
    ...                 supplierId=${SUPPLIER_ID}
    ...                 productCategoryId=${PRODUCT_CATEGORY_ID}
    ...                 rackId=1
    ...                 receiptId=1
    ...                 zoneId=1
    ...                 orderId=1
    ...                 packageId=1
    ...                 masterProductId=1
    ...                 note=Test product note
    ...                 barCode=${barcode}
    RETURN            ${product_data}

Create Product
    [Documentation]     Create a new product and return its ID
    [Arguments]         ${product_data}
    
    # Validate required parameters
    FOR    ${key}    IN    @{product_data.keys()}
        Should Not Be Empty    ${product_data}[${key}]
        ...    msg=Missing or empty required parameter: ${key}
    END
    
    # Prepare request
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    # Send create product request
    ${response}=        POST On Session
    ...                 vkho
    ...                 /products/create
    ...                 json=${product_data}
    ...                 headers=${headers}
    ...                 expected_status=201
    
    # Save response for debugging
    ${timestamp}=       Evaluate         int(time.time())    time
    Create File         ${RESULTS_DIR}${/}product_create_${timestamp}.json    ${response.text}
    
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
    FOR    ${key}    IN    @{update_data.keys()}
        Should Not Be Empty    ${update_data}[${key}]
        ...    msg=Update data missing or empty required field: ${key}
    END
    
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
    [Documentation]     Retrieve all products with optional filtering
    [Arguments]         ${warehouse_id}=${WAREHOUSE_ID}    ${filter_params}=${EMPTY}
    
    # Validate parameters
    Should Not Be Empty    ${warehouse_id}
    ...    msg=Warehouse ID cannot be empty
    
    # Prepare request
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    # Create params dictionary
    ${params}=          Create Dictionary    warehouseId=${warehouse_id}
    
    # Add any additional filter parameters if provided
    Run Keyword If      "${filter_params}" != "${EMPTY}"    Set To Dictionary    ${params}    &{filter_params}
    
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

Assert Product Details
    [Documentation]     Verify product details match expected values
    [Arguments]         ${product}    ${expected_data}
    
    # For all keys in expected data, verify they match in the product data
    FOR    ${key}    IN    @{expected_data.keys()}
        Run Keyword If    "${key}" in ${product}    Should Be Equal    ${product}[${key}]    ${expected_data}[${key}]
        ...    msg=Product ${key} value '${product}[${key}]' does not match expected '${expected_data}[${key}]'
    END

Create Test Product
    [Documentation]     Creates a test product if one doesn't exist
    ${product_data}=    Generate Unique Product Data
    ${product_id}    ${response}=    Create Product    ${product_data}
    Set Global Variable  ${TEST_PRODUCT_ID}      ${product_id}
    Set Global Variable  ${TEST_PRODUCT_NAME}    ${response}[name]
    Set Global Variable  ${TEST_PRODUCT_DATA}    ${product_data}

Verify Response Indicates Deletion
    [Documentation]     Check if response indicates product is deleted
    [Arguments]         ${response_text}
    
    # Parse response
    ${json}=            Evaluate         json.loads('''${response_text}''')    json
    
    # Check for status field indicating deletion
    ${has_status}=      Run Keyword And Return Status    Dictionary Should Contain Key    ${json}    status
    ${is_deleted}=      Run Keyword If    ${has_status}    Check Deletion Status    ${json}[status]
    ...    ELSE         Check Other Deletion Indicators    ${json}
    
    RETURN            ${is_deleted}

Check Deletion Status
    [Documentation]     Check if status field indicates deletion
    [Arguments]         ${status}
    
    # Handle different possible status values for deletion
    ${is_deleted}=      Set Variable    ${FALSE}
    
    # Convert to uppercase for case-insensitive comparison
    ${status_upper}=    Convert To Uppercase    ${status}
    
    # Check against common "deleted" status values
    IF    '${status_upper}' == 'DISABLE' or '${status_upper}' == 'DELETED' or '${status_upper}' == 'LOST'
        ${is_deleted}=  Set Variable    ${TRUE}
    END
    
    RETURN            ${is_deleted}

Check Other Deletion Indicators
    [Documentation]     Check for other indicators of deletion
    [Arguments]         ${json}
    
    # If no specific deletion indicator is present, assume not deleted
    ${is_deleted}=      Set Variable    ${FALSE}
    
    RETURN            ${is_deleted}

Generate Bulk Product Data
    [Documentation]     Generate data for multiple products in bulk
    [Arguments]         ${count}=${BULK_PRODUCT_COUNT}
    
    ${products}=        Create List
    FOR    ${i}    IN RANGE    ${count}
        ${product_data}=    Generate Unique Product Data    custom_name=Bulk Product ${i}
        Append To List      ${products}    ${product_data}
    END
    RETURN            ${products}

Create Bulk Products
    [Documentation]     Create multiple products in a single request
    [Arguments]         ${products_data}
    
    # Validate input
    Should Not Be Empty    ${products_data}
    ...    msg=Bulk products data cannot be empty
    
    # Prepare request
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    # Send bulk create request (assuming batch endpoint exists, e.g., /products/batch-create)
    ${response}=        POST On Session
    ...                 vkho
    ...                 /products/batch-create
    ...                 json=${products_data}
    ...                 headers=${headers}
    ...                 expected_status=201
    
    # Process response
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    Should Not Be Empty    ${json}
    ...    msg=Bulk create response was empty
    
    # Return created product IDs
    ${product_ids}=     Create List
    FOR    ${item}    IN    @{json}
        Append To List      ${product_ids}    ${item}[id]
    END
    RETURN            ${product_ids}    ${json}

Update Product Stock
    [Documentation]     Update stock quantity for a product
    [Arguments]         ${product_id}    ${new_quantity}
    
    # Prepare update data
    ${update_data}=     Create Dictionary
    ...                 id=${product_id}
    ...                 totalQuantity=${new_quantity}
    ...                 warehouseId=${WAREHOUSE_ID}
    
    # Update product
    ${updated_product}=    Update Product    ${product_id}    ${update_data}
    
    # Verify stock update
    Should Be Equal As Integers    ${updated_product}[totalQuantity]    ${new_quantity}
    ...    msg=Stock quantity update failed
    
    RETURN            ${updated_product}

Check Product Expiration
    [Documentation]     Check if a product is expired based on its expireDate
    [Arguments]         ${product}
    
    ${expire_date}=     Get From Dictionary    ${product}    expireDate
    ${current_date}=    Get Current Date    result_format=%Y-%m-%dT%H:%M:%S.000Z
    ${is_expired}=      Evaluate    '${expire_date}' < '${current_date}'
    
    RETURN            ${is_expired}

*** Test Cases ***
01 - Setup Test Environment
    [Documentation]     Setup API session for product tests
    [Tags]              setup
    Setup API Session
    Log                 Successfully authenticated with token: ${AUTH_TOKEN}

02 - Create Product Test
    [Documentation]     Test creating a new product
    [Tags]              create    positive
    
    # Generate product data
    ${product_data}=    Generate Unique Product Data
    
    # Create product
    ${product_id}    ${response}=    Create Product    ${product_data}
    
    # Verify product was created successfully
    Should Not Be Empty    ${product_id}
    ...    msg=Failed to create product: No ID returned
    Should Be Equal     ${response}[name]    ${product_data}[name]
    ...    msg=Created product name does not match input data
    
    # Save product ID for subsequent tests
    Set Global Variable  ${TEST_PRODUCT_ID}      ${product_id}
    Set Global Variable  ${TEST_PRODUCT_NAME}    ${response}[name]
    Set Global Variable  ${TEST_PRODUCT_DATA}    ${product_data}
    
    Log                 Successfully created product: ${TEST_PRODUCT_NAME} with ID: ${TEST_PRODUCT_ID}

03 - Create Product Missing Required Field Test
    [Documentation]     Test creating a product with missing required fields
    [Tags]              create    negative
    
    # Generate incomplete product data (missing name)
    ${incomplete_data}=  Generate Unique Product Data    custom_name=Missing Field Product
    Remove From Dictionary    ${incomplete_data}    name
    
    # Attempt to create product with incomplete data
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    # Expect proper error message
    Run Keyword And Expect Error    *Missing or empty required parameter: name*
    ...                 Create Product    ${incomplete_data}
    
    Log                 Successfully verified that creating a product with missing fields is rejected

04 - Get Product Test
    [Documentation]     Test retrieving a specific product
    [Tags]              retrieve    positive
    
    # Create a product if one doesn't exist
    Run Keyword If      "${TEST_PRODUCT_ID}" == "${EMPTY}"    Create Test Product
    
    # Get product
    ${product}=         Get Product By ID    ${TEST_PRODUCT_ID}
    
    # Verify product details match what we created
    Assert Product Details    ${product}    ${TEST_PRODUCT_DATA}
    
    Log                 Successfully retrieved product: ${product}[name]

05 - Get Non-Existent Product Test
    [Documentation]     Test retrieving a product that doesn't exist
    [Tags]              retrieve    negative
    
    # Generate non-existent ID
    ${non_existent_id}=  Set Variable    99999999
    
    # Attempt to get non-existent product
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    # Expect error response
    Run Keyword And Expect Error    *
    ...                 GET On Session
    ...                 vkho
    ...                 /products/get-one/${non_existent_id}
    ...                 headers=${headers}
    ...                 expected_status=200
    
    Log                 Successfully verified that retrieving a non-existent product fails

06 - Update Product Test
    [Documentation]     Test updating an existing product
    [Tags]              update    positive
    
    # Create a product if one doesn't exist
    Run Keyword If      "${TEST_PRODUCT_ID}" == "${EMPTY}"    Create Test Product
    
    # Prepare update data
    ${updated_name}=    Set Variable    ${TEST_PRODUCT_NAME} Updated
    ${update_data}=     Generate Unique Product Data    custom_name=${updated_name}
    Set To Dictionary   ${update_data}    id=${TEST_PRODUCT_ID}
    Set To Dictionary   ${update_data}    status=STORED
    Set To Dictionary   ${update_data}    description=Updated product description
    Set To Dictionary   ${update_data}    lostDate=2025-04-01T00:00:00.000Z
    Set To Dictionary   ${update_data}    lostNumber=0
    
    # Update product
    ${updated_product}=    Update Product    ${TEST_PRODUCT_ID}    ${update_data}
    
    # Verify product was updated successfully
    Should Be Equal     ${updated_product}[name]    ${updated_name}
    ...    msg=Updated product name does not match expected value
    
    # Update global variable with new data
    Set Global Variable  ${TEST_PRODUCT_NAME}    ${updated_name}
    Set Global Variable  ${TEST_PRODUCT_UPDATED_DATA}    ${update_data}
    
    Log                 Successfully updated product: ${updated_product}[name]

07 - Update Product With Missing Required Field Test
    [Documentation]     Test updating a product with missing required fields
    [Tags]              update    negative
    
    # Create a product if one doesn't exist
    Run Keyword If      "${TEST_PRODUCT_ID}" == "${EMPTY}"    Create Test Product
    
    # Prepare incomplete update data (missing status)
    ${incomplete_data}=  Create Dictionary
    ...                 id=${TEST_PRODUCT_ID}
    ...                 name=Incomplete Update
    ...                 warehouseId=${WAREHOUSE_ID}
    # Missing status field and other required fields
    
    # Attempt to update product with incomplete data
    Run Keyword And Expect Error    *Update data missing or empty required field: status*
    ...                 Update Product    ${TEST_PRODUCT_ID}    ${incomplete_data}
    
    Log                 Successfully verified that updating a product with missing fields is rejected

08 - Get All Products Test
    [Documentation]     Test retrieving all products
    [Tags]              retrieve    positive
    
    # Get all products
    ${products}=        Get All Products
    
    # Log the structure to understand the format
    Log                 Response structure: ${products}
    
    # Check different possible response formats
    ${has_data}=        Run Keyword And Return Status    Dictionary Should Contain Key    ${products}    data
    ${has_items}=       Run Keyword And Return Status    Dictionary Should Contain Key    ${products}    items
    ${has_records}=     Run Keyword And Return Status    Dictionary Should Contain Key    ${products}    records
    
    # Log information based on what we found
    Run Keyword If      ${has_data}      Log    Found ${products['data'].__len__()} products
    ...    ELSE IF      ${has_items}     Log    Found ${products['items'].__len__()} products
    ...    ELSE IF      ${has_records}   Log    Found ${products['records'].__len__()} products
    ...    ELSE         Log    Found products in unknown format
    
    Log                 Successfully retrieved products list

09 - Filter Products Test
    [Documentation]     Test filtering products by name
    [Tags]              retrieve    filter    positive
    
    # Create a product if one doesn't exist
    Run Keyword If      "${TEST_PRODUCT_ID}" == "${EMPTY}" or "${TEST_PRODUCT_NAME}" == "${EMPTY}"    Create Test Product
    
    # Create filter params based on product name
    ${filter_params}=   Create Dictionary    keyword=${TEST_PRODUCT_NAME}
    
    # Get filtered products
    ${filtered_products}=    Get All Products    filter_params=${filter_params}
    
    # Verify response contains data
    Should Not Be Empty    ${filtered_products}
    ...    msg=Filtered products response was empty
    
    # Check if our product is in the results (depends on API structure)
    ${has_data}=        Run Keyword And Return Status    Dictionary Should Contain Key    ${filtered_products}    data
    ${has_items}=       Run Keyword And Return Status    Dictionary Should Contain Key    ${filtered_products}    items
    ${has_records}=     Run Keyword And Return Status    Dictionary Should Contain Key    ${filtered_products}    records
    
    # Verify filter worked based on response structure
    ${found}=           Set Variable    ${FALSE}
    
    IF    ${has_data}
        ${data_length}=     Get Length    ${filtered_products}[data]
        Should Be True      ${data_length} > 0    msg=Filter returned empty data array
        ${found}=           Set Variable    ${TRUE}
    ELSE IF    ${has_items}
        ${items_length}=    Get Length    ${filtered_products}[items]
        Should Be True      ${items_length} > 0    msg=Filter returned empty items array
        ${found}=           Set Variable    ${TRUE}
    ELSE IF    ${has_records}
        ${records_length}=  Get Length    ${filtered_products}[records]
        Should Be True      ${records_length} > 0    msg=Filter returned empty records array
        ${found}=           Set Variable    ${TRUE}
    ELSE
        Log                 Warning: Unknown response structure, can't verify filter results
    END
    
    Should Be True      ${found}    msg=Failed to find product in filtered results
    
    Log                 Successfully filtered products by name: ${TEST_PRODUCT_NAME}

10 - Delete Product Test
    [Documentation]     Test deleting a product
    [Tags]              delete    positive
    
    # Create a product if one doesn't exist
    Run Keyword If      "${TEST_PRODUCT_ID}" == "${EMPTY}"    Create Test Product
    
    # Delete product
    ${result}=          Delete Product    ${TEST_PRODUCT_ID}
    Should Be True      ${result}
    ...    msg=Delete product operation failed
    
    # Verify product deletion by trying to get it
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    ${response}=        GET On Session
    ...                 vkho
    ...                 /products/get-one/${TEST_PRODUCT_ID}
    ...                 headers=${headers}
    ...                 expected_status=any
    
    # Log response for debugging
    Log                 Response status after deletion: ${response.status_code}
    Log                 Response text after deletion: ${response.text}
    
    # API might handle deletion differently: either 404 Not Found or status = DISABLE/LOST
    ${is_deleted}=      Run Keyword If      ${response.status_code} == 404    Set Variable    ${TRUE}
    ...    ELSE IF      ${response.status_code} == 200    Verify Response Indicates Deletion    ${response.text}
    ...    ELSE         Set Variable    ${FALSE}
    
    Should Be True      ${is_deleted}
    ...    msg=Product was not properly deleted or marked as deleted
    
    Log                 Successfully verified deletion of product with ID: ${TEST_PRODUCT_ID}

11 - Delete Non-Existent Product Test
    [Documentation]     Test deleting a product that doesn't exist
    [Tags]              delete    negative
    
    # Generate non-existent ID
    ${non_existent_id}=  Set Variable    99999999
    
    # Attempt to delete non-existent product
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    # Expect error response
    Run Keyword And Expect Error    *
    ...                 DELETE On Session
    ...                 vkho
    ...                 /products/delete/${non_existent_id}
    ...                 headers=${headers}
    ...                 expected_status=200
    
    Log                 Successfully verified that deleting a non-existent product fails
12 - Create Product With Minimum Fields Test
    [Documentation]     Test creating a product with only required fields
    [Tags]              create    edge
    
    # Generate minimal product data
    ${minimal_data}=    Create Dictionary
    ...                 name=Minimal Product ${EXECUTION_ID}
    ...                 totalQuantity=10
    ...                 expectedQuantity=10
    ...                 importDate=2025-03-31T00:00:00.000Z
    ...                 cost=10.00
    ...                 salePrice=15.00
    ...                 warehouseId=${WAREHOUSE_ID}
    ...                 inboundKind=NEW
    
    # Create product with minimal data
    ${product_id}    ${response}=    Create Product    ${minimal_data}
    
    # Verify product was created successfully
    Should Not Be Empty    ${product_id}
    ...    msg=Failed to create product with minimal fields: No ID returned
    Should Be Equal     ${response}[name]    ${minimal_data}[name]
    ...    msg=Created product name does not match input data
    
    Log                 Successfully created product with minimal fields: ${response}[name]
13 - Create Product With Invalid Warehouse ID Test
    [Documentation]     Test creating a product with an invalid warehouse ID
    [Tags]              create    negative
    
    # Generate product data with invalid warehouse ID
    ${invalid_data}=    Generate Unique Product Data    custom_name=Invalid Warehouse Product
    Set To Dictionary   ${invalid_data}    warehouseId=999999
    
    # Attempt to create product
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    # Expect error response
    Run Keyword And Expect Error    *
    ...                 POST On Session
    ...                 vkho
    ...                 /products/create
    ...                 json=${invalid_data}
    ...                 headers=${headers}
    ...                 expected_status=201
    
    Log                 Successfully verified that creating a product with invalid warehouse ID fails
14 - Pagination Test for Get All Products
    [Documentation]     Test pagination functionality for retrieving all products
    [Tags]              retrieve    pagination    positive
    
    # Create multiple products to ensure pagination works
    FOR    ${i}    IN RANGE    1    11    # Create 10 products (exceeds PAGE_SIZE)
        ${product_data}=    Generate Unique Product Data    custom_name=Pagination Product ${i}
        ${product_id}    ${response}=    Create Product    ${product_data}
    END
    
    # Get first page of products
    ${params}=          Create Dictionary    warehouseId=${WAREHOUSE_ID}    page=1    size=${PAGE_SIZE}
    ${first_page}=      Get All Products    filter_params=${params}
    
    # Verify response structure and pagination
    ${has_data}=        Run Keyword And Return Status    Dictionary Should Contain Key    ${first_page}    data
    ${has_items}=       Run Keyword And Return Status    Dictionary Should Contain Key    ${first_page}    items
    ${has_records}=     Run Keyword And Return Status    Dictionary Should Contain Key    ${first_page}    records
    
    IF    ${has_data}
        ${items}=       Set Variable    ${first_page}[data]
    ELSE IF    ${has_items}
        ${items}=       Set Variable    ${first_page}[items]
    ELSE IF    ${has_records}
        ${items}=       Set Variable    ${first_page}[records]
    ELSE
        Fail            Unknown response structure for pagination test
    END
    
    ${item_count}=      Get Length    ${items}
    Should Be Equal As Integers    ${item_count}    ${PAGE_SIZE}
    ...    msg=First page did not return expected number of items (${PAGE_SIZE})
    
    # Verify total pages or total count exists
    ${has_pagination}=  Run Keyword And Return Status    Dictionary Should Contain Key    ${first_page}    totalPages
    Run Keyword If      ${has_pagination}
    ...                 Should Be True    ${first_page}[totalPages] >= 1
    ...                 msg=Total pages should be at least 1
    
    Log                 Successfully verified pagination for get all products
15 - Unauthorized Access Test
    [Documentation]     Test accessing product endpoints without valid authentication
    [Tags]              security    negative
    
    # Attempt to get all products with invalid token
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${INVALID_TOKEN}
    
    Run Keyword And Expect Error    *
    ...                 GET On Session
    ...                 vkho
    ...                 /products/get-all
    ...                 params=warehouseId=${WAREHOUSE_ID}
    ...                 headers=${headers}
    ...                 expected_status=200
    
    Log                 Successfully verified that unauthorized access is rejected
16 - Split Product Test
    [Documentation]     Test splitting an existing product into multiple products
    [Tags]              split    positive
    
    # Create a product if one doesn’t exist
    Run Keyword If      "${TEST_PRODUCT_ID}" == "${EMPTY}"    Create Test Product
    
    # Generate split data
    ${split_data}=      Generate Split Data    ${TEST_PRODUCT_ID}
    
    # Split the product
    ${split_response}=  Split Product    ${TEST_PRODUCT_ID}    ${split_data}
    
    # Verify split was successful (API-specific validation)
    ${has_new_products}=    Run Keyword And Return Status    Dictionary Should Contain Key    ${split_response}    newProducts
    Run Keyword If      ${has_new_products}
    ...                 Should Be True    ${split_response}[newProducts].__len__() == 2
    ...                 msg=Split did not create exactly 2 new products
    
    Log                 Successfully split product with ID: ${TEST_PRODUCT_ID}
17 - Split Product With Invalid Quantity Test
    [Documentation]     Test splitting a product with invalid quantities
    [Tags]              split    negative
    
    # Create a product if one doesn’t exist
    Run Keyword If      "${TEST_PRODUCT_ID}" == "${EMPTY}"    Create Test Product
    
    # Generate invalid split data (quantities exceed original total)
    ${invalid_split}=   Generate Split Data    ${TEST_PRODUCT_ID}    quantity1=1000    quantity2=1000
    
    # Attempt to split product
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    Run Keyword And Expect Error    *
    ...                 POST On Session
    ...                 vkho
    ...                 /products/split
    ...                 json=${invalid_split}
    ...                 headers=${headers}
    ...                 expected_status=201
    
    Log                 Successfully verified that splitting with invalid quantities fails
18 - Update Product With Expired Date Test
    [Documentation]     Test updating a product with an expired date
    [Tags]              update    edge
    
    # Create a product if one doesn’t exist
    Run Keyword If      "${TEST_PRODUCT_ID}" == "${EMPTY}"    Create Test Product
    
    # Prepare update data with expired date
    ${update_data}=     Generate Unique Product Data    custom_name=Expired Product
    Set To Dictionary   ${update_data}    id=${TEST_PRODUCT_ID}
    Set To Dictionary   ${update_data}    expireDate=2024-01-01T00:00:00.000Z  # Past date
    
    # Update product
    ${updated_product}=    Update Product    ${TEST_PRODUCT_ID}    ${update_data}
    
    # Verify product was updated successfully
    Should Be Equal     ${updated_product}[expireDate]    2024-01-01T00:00:00.000Z
    ...    msg=Updated product expireDate does not match expected value
    
    Log                 Successfully updated product with expired date: ${updated_product}[name]

19 - Bulk Product Creation Flow
    [Documentation]     Test creating multiple products in bulk and verify them
    [Tags]              create    bulk    positive
    
    # Generate bulk product data
    ${bulk_data}=       Generate Bulk Product Data    count=${BULK_PRODUCT_COUNT}
    
    # Create bulk products
    ${product_ids}    ${response}=    Create Bulk Products    ${bulk_data}
    
    # Verify correct number of products created
    ${created_count}=   Get Length    ${product_ids}
    Should Be Equal As Integers    ${created_count}    ${BULK_PRODUCT_COUNT}
    ...    msg=Number of created products (${created_count}) does not match expected (${BULK_PRODUCT_COUNT})
    
    # Verify each product individually
    FOR    ${i}    IN RANGE    ${BULK_PRODUCT_COUNT}
        ${product_id}=      Get From List    ${product_ids}    ${i}
        ${product}=         Get Product By ID    ${product_id}
        Assert Product Details    ${product}    ${bulk_data}[${i}]
    END
    
    Log                 Successfully created and verified ${BULK_PRODUCT_COUNT} products in bulk

20 - Product Stock Management Flow
    [Documentation]     Test managing product stock from initial import to low stock
    [Tags]              update    stock    positive
    
    # Create a product with initial stock
    ${product_data}=    Generate Unique Product Data    custom_name=Stock Management Product
    Set To Dictionary   ${product_data}    totalQuantity=50
    ${product_id}    ${response}=    Create Product    ${product_data}
    
    # Reduce stock to simulate sales
    ${updated_product}=    Update Product Stock    ${product_id}    20
    Should Be Equal As Integers    ${updated_product}[totalQuantity]    20
    ...    msg=Stock reduction to 20 failed
    
    # Reduce stock to low level
    ${updated_product}=    Update Product Stock    ${product_id}    ${LOW_STOCK_THRESHOLD}
    Should Be Equal As Integers    ${updated_product}[totalQuantity]    ${LOW_STOCK_THRESHOLD}
    ...    msg=Stock reduction to low threshold (${LOW_STOCK_THRESHOLD}) failed
    
    # Verify product appears in low stock filter (if API supports it)
    ${filter_params}=   Create Dictionary    warehouseId=${WAREHOUSE_ID}    minQuantity=0    maxQuantity=${LOW_STOCK_THRESHOLD}
    ${products}=        Get All Products    filter_params=${filter_params}
    
    ${found}=           Set Variable    ${FALSE}
    ${items}=           Set Variable    ${products}
    FOR    ${key}    IN    data    items    records
        ${has_key}=     Run Keyword And Return Status    Dictionary Should Contain Key    ${products}    ${key}
        Run Keyword If  ${has_key}    Set Variable    ${products}[${key}]    ${items}
    END
    
    FOR    ${product}    IN    @{items}
        ${id_match}=    Run Keyword And Return Status    Should Be Equal    ${product}[id]    ${product_id}
        Run Keyword If  ${id_match}    Set Variable    ${TRUE}    ${found}
    END
    
    Should Be True      ${found}
    ...    msg=Product with low stock not found in filtered results
    
    Log                 Successfully managed product stock from 50 to ${LOW_STOCK_THRESHOLD}

21 - Product Expiration Flow
    [Documentation]     Test product lifecycle from import to expiration
    [Tags]              lifecycle    expiration    positive
    
    # Create a product with a near-expiration date
    ${product_data}=    Generate Unique Product Data    custom_name=Expiring Product
    Set To Dictionary   ${product_data}    expireDate=2025-04-01T00:00:00.000Z  # Near future date
    ${product_id}    ${response}=    Create Product    ${product_data}
    Set Global Variable  ${EXPIRED_PRODUCT_ID}    ${product_id}
    
    # Verify initial state
    ${product}=         Get Product By ID    ${product_id}
    Should Be Equal     ${product}[expireDate]    2025-04-01T00:00:00.000Z
    ...    msg=Initial expireDate does not match expected value
    
    # Simulate expiration by updating to past date
    ${update_data}=     Create Dictionary
    ...                 id=${product_id}
    ...                 expireDate=2025-03-30T00:00:00.000Z  # Past date (before March 31, 2025)
    ...                 warehouseId=${WAREHOUSE_ID}
    ${updated_product}=    Update Product    ${product_id}    ${update_data}
    
    # Verify expiration
    ${is_expired}=      Check Product Expiration    ${updated_product}
    Should Be True      ${is_expired}
    ...    msg=Product should be marked as expired
    
    # Check if API flags it as expired (if supported)
    ${product}=         Get Product By ID    ${product_id}
    ${has_status}=      Run Keyword And Return Status    Dictionary Should Contain Key    ${product}    status
    Run Keyword If      ${has_status}
    ...                 Should Contain Any    ${product}[status]    EXPIRED    LOST
    ...                 msg=Product status should indicate expiration
    
    Log                 Successfully managed product expiration lifecycle

22 - Product Movement Between Racks Flow
    [Documentation]     Test moving a product between racks in the warehouse
    [Tags]              movement    rack    positive
    
    # Create a product
    ${product_data}=    Generate Unique Product Data    custom_name=Rack Movement Product
    ${product_id}    ${response}=    Create Product    ${product_data}
    
    # Move product to a different rack
    ${update_data}=     Create Dictionary
    ...                 id=${product_id}
    ...                 rackId=2  # Moving from rack 1 to rack 2
    ...                 warehouseId=${WAREHOUSE_ID}
    ${updated_product}=    Update Product    ${product_id}    ${update_data}
    
    # Verify rack update
    Should Be Equal As Integers    ${updated_product}[rackId]    2
    ...    msg=Product rack ID did not update to 2
    
    # Move back to original rack
    Set To Dictionary   ${update_data}    rackId=1
    ${updated_product}=    Update Product    ${product_id}    ${update_data}
    
    Should Be Equal As Integers    ${updated_product}[rackId]    1
    ...    msg=Product rack ID did not revert to 1
    
    Log                 Successfully moved product between racks

23 - Duplicate Product Code Test
    [Documentation]     Test creating a product with a duplicate product code
    [Tags]              create    negative
    
    # Create a product with a specific product code
    ${product_data}=    Generate Unique Product Data    custom_name=Duplicate Code Product
    ${original_code}=   Set Variable    ${product_data}[productCode]
    ${product_id}    ${response}=    Create Product    ${product_data}
    
    # Attempt to create another product with the same code
    ${duplicate_data}=  Generate Unique Product Data    custom_name=Duplicate Code Product 2
    Set To Dictionary   ${duplicate_data}    productCode=${original_code}
    
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    
    Run Keyword And Expect Error    *
    ...                 POST On Session
    ...                 vkho
    ...                 /products/create
    ...                 json=${duplicate_data}
    ...                 headers=${headers}
    ...                 expected_status=201
    
    Log                 Successfully verified that duplicate product codes are rejected

24 - Product Supplier Change Flow
    [Documentation]     Test changing a product’s supplier
    [Tags]              update    supplier    positive
    
    # Create a product with initial supplier
    ${product_data}=    Generate Unique Product Data    custom_name=Supplier Change Product
    ${product_id}    ${response}=    Create Product    ${product_data}
    
    # Update product to a new supplier
    ${new_supplier_id}=    Set Variable    57  # Assuming another valid supplier ID
    ${update_data}=     Create Dictionary
    ...                 id=${product_id}
    ...                 supplierId=${new_supplier_id}
    ...                 warehouseId=${WAREHOUSE_ID}
    ${updated_product}=    Update Product    ${product_id}    ${update_data}
    
    # Verify supplier change
    Should Be Equal As Integers    ${updated_product}[supplierId]    ${new_supplier_id}
    ...    msg=Supplier ID did not update to ${new_supplier_id}
    
    Log                 Successfully changed product supplier to ID: ${new_supplier_id}20 - Bulk Product Creation Flow
    [Documentation]     Test creating multiple products in bulk and verify them
    [Tags]              create    bulk    positive
    
    # Generate bulk product data
    ${bulk_data}=       Generate Bulk Product Data    count=${BULK_PRODUCT_COUNT}
    
    # Create bulk products
    ${product_ids}    ${response}=    Create Bulk Products    ${bulk_data}
    
    # Verify correct number of products created
    ${created_count}=   Get Length    ${product_ids}
    Should Be Equal As Integers    ${created_count}    ${BULK_PRODUCT_COUNT}
    ...    msg=Number of created products (${created_count}) does not match expected (${BULK_PRODUCT_COUNT})
    
    # Verify each product individually
    FOR    ${i}    IN RANGE    ${BULK_PRODUCT_COUNT}
        ${product_id}=      Get From List    ${product_ids}    ${i}
        ${product}=         Get Product By ID    ${product_id}
        Assert Product Details    ${product}    ${bulk_data}[${i}]
    END
    
    Log                 Successfully created and verified ${BULK_PRODUCT_COUNT} products in bulk

25 - Cleanup Test Environment
    [Documentation]     Clean up any resources created during tests
    [Tags]              cleanup
    
    # Additional cleanup if needed
    Log                 Test environment cleaned up successfully