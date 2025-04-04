*** Settings ***
Documentation     End-to-End Test Suite for Inventory Management with Dynamic Pricing, Supplier Returns, and Synchronization
...               Tests product lifecycle, pricing adjustments, returns, and multi-warehouse stock synchronization
...               Includes positive, negative, missing parameters, and edge case validations
Library           RequestsLibrary
Library           Collections
Library           OperatingSystem
Library           String
Library           DateTime
Library           BuiltIn
Resource          ../../Variables/variables.robot

*** Keywords ***
Setup Manager Session
    [Documentation]     Create API session and authenticate with manager credentials
    Create Session      vkho             ${BASE_URL}      verify=True    disable_warnings=True
    ${headers}=         Create Dictionary    Content-Type=application/json
    ${body}=            Create Dictionary    username=${MANAGER_USERNAME}    password=${MANAGER_PASSWORD}
    ${response}=        POST On Session
    ...                 vkho
    ...                 /auth/login
    ...                 json=${body}
    ...                 headers=${headers}
    ...                 expected_status=201
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    ${token}=           Set Variable     Bearer ${json}[access_token]
    Set Global Variable  ${MANAGER_TOKEN}    ${token}
    Create Directory    ${RESULTS_DIR}

Generate Warehouse Data
    [Arguments]         ${name_suffix}=${EMPTY}
    ${timestamp}=       Evaluate         int(time.time())    time
    ${warehouse_data}=  Create Dictionary
    ...                 name=Warehouse ${name_suffix} ${timestamp}
    ...                 address=303 Dynamic Ave ${name_suffix}
    ...                 acreage=9000
    RETURN            ${warehouse_data}

Generate Rack Data
    [Arguments]         ${warehouse_id}    ${capacity}=${MAX_QUANTITY}
    ${rack_data}=      Create Dictionary
    ...                 capacity=${capacity}
    ...                 warehouseId=${warehouse_id}
    ...                 shelfId=1
    RETURN            ${rack_data}

Generate Supplier Data
    ${timestamp}=       Evaluate         int(time.time())    time
    ${supplier_data}=   Create Dictionary
    ...                 name=Dynamic Supplier ${timestamp}
    ...                 phone=987-654-3210
    ...                 address=404 Supplier Ln
    ...                 email=dynamic${timestamp}@example.com
    ...                 supplierCode=DYN-${timestamp}
    RETURN            ${supplier_data}

Generate Master Product Data
    [Arguments]         ${warehouse_id}    ${supplier_ids}    ${purchase_price}=50.00    ${sale_price}=100.00    ${retail_price}=120.00
    ${timestamp}=       Evaluate         int(time.time())    time
    ${master_data}=     Create Dictionary
    ...                 name=Dynamic Master ${timestamp}
    ...                 capacity=1500
    ...                 method=FIFO
    ...                 stogareTime=90
    ...                 image=https://example.com/dynamic-master.jpg
    ...                 warehouseId=${warehouse_id}
    ...                 productCategoryId=1
    ...                 supplierIds=${supplier_ids}
    ...                 purchasePrice=${purchase_price}
    ...                 salePrice=${sale_price}
    ...                 retailPrice=${retail_price}
    ...                 barCode=BAR-DM${timestamp}
    ...                 VAT=10
    ...                 DVT=unit
    ...                 packing=box
    ...                 length=30
    ...                 width=30
    ...                 height=30
    ...                 itemCode=ITEM-D${timestamp}
    ...                 description=Master product with dynamic pricing
    ...                 isActive=${TRUE}
    ...                 discount=0
    ...                 isResources=${FALSE}
    ...                 availableQuantity=10000
    RETURN            ${master_data}

Generate Product Data
    [Arguments]         ${warehouse_id}    ${master_id}    ${rack_id}    ${supplier_id}    ${quantity}=2000    ${cost}=50.00    ${sale_price}=100.00
    ${timestamp}=       Evaluate         int(time.time())    time
    ${product_data}=    Create Dictionary
    ...                 name=Dynamic Product ${timestamp}
    ...                 totalQuantity=${quantity}
    ...                 expectedQuantity=${quantity}
    ...                 importDate=${CURRENT_DATE}
    ...                 cost=${cost}
    ...                 salePrice=${sale_price}
    ...                 warehouseId=${warehouse_id}
    ...                 inboundKind=NEW
    ...                 expireDate=2025-12-31T00:00:00Z
    ...                 productCode=DYN-${timestamp}
    ...                 idRackReallocate=${rack_id}
    ...                 imageProduct=https://example.com/dynamic-product.jpg
    ...                 imageQRCode=https://example.com/qr-dynamic.jpg
    ...                 imageBarcode=https://example.com/barcode-dynamic.jpg
    ...                 blockId=1
    ...                 supplierId=${supplier_id}
    ...                 productCategoryId=1
    ...                 rackId=${rack_id}
    ...                 receiptId=1
    ...                 zoneId=1
    ...                 orderId=1
    ...                 packageId=1
    ...                 masterProductId=${master_id}
    ...                 note=Product with dynamic pricing
    ...                 barCode=BAR-DP${timestamp}
    RETURN            ${product_data}

Create Warehouse
    [Arguments]         ${warehouse_data}
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${MANAGER_TOKEN}
    ${response}=        POST On Session    vkho    /warehouses/create    json=${warehouse_data}    headers=${headers}    expected_status=201
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    RETURN            ${json}[id]    ${json}

Create Rack
    [Arguments]         ${rack_data}
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${MANAGER_TOKEN}
    ${response}=        POST On Session    vkho    /racks/create    json=${rack_data}    headers=${headers}    expected_status=201
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    RETURN            ${json}[id]    ${json}

Create Supplier
    [Arguments]         ${supplier_data}
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${MANAGER_TOKEN}
    ${response}=        POST On Session    vkho    /suppliers/create    json=${supplier_data}    headers=${headers}    expected_status=201
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    RETURN            ${json}[id]    ${json}

Create Master Product
    [Arguments]         ${master_data}
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${MANAGER_TOKEN}
    ${response}=        POST On Session    vkho    /master-products/create    json=${master_data}    headers=${headers}    expected_status=any
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    RETURN            ${response.status_code}    ${json}

Create Product
    [Arguments]         ${product_data}
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${MANAGER_TOKEN}
    ${response}=        POST On Session    vkho    /products/create    json=${product_data}    headers=${headers}    expected_status=any
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    RETURN            ${response.status_code}    ${json}

Add Product To Rack
    [Arguments]         ${rack_id}    ${product_ids}
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${MANAGER_TOKEN}
    ${rack_data}=       Create Dictionary    rackId=${rack_id}    productIds=${product_ids}
    ${response}=        POST On Session    vkho    /products/add/rack    json=${rack_data}    headers=${headers}    expected_status=any
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    RETURN            ${response.status_code}    ${json}

Update Master Pricing
    [Documentation]     Update master product pricing
    [Arguments]         ${master_id}    ${purchase_price}    ${sale_price}    ${retail_price}
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${MANAGER_TOKEN}
    ${update_data}=     Create Dictionary
    ...                 id=${master_id}
    ...                 purchasePrice=${purchase_price}
    ...                 salePrice=${sale_price}
    ...                 retailPrice=${retail_price}
    ${response}=        POST On Session    vkho    /master-products/update    json=${update_data}    headers=${headers}    expected_status=any
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    RETURN            ${response.status_code}    ${json}

Update Product Pricing
    [Documentation]     Update product pricing
    [Arguments]         ${product_id}    ${cost}    ${sale_price}
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${MANAGER_TOKEN}
    ${update_data}=     Create Dictionary
    ...                 id=${product_id}
    ...                 cost=${cost}
    ...                 salePrice=${sale_price}
    ...                 status=STOCKED
    ${response}=        POST On Session    vkho    /products/update    json=${update_data}    headers=${headers}    expected_status=any
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    RETURN            ${response.status_code}    ${json}

Process Supplier Return
    [Documentation]     Process a supplier return by splitting and updating status
    [Arguments]         ${product_id}    ${quantity}    ${supplier_id}
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${MANAGER_TOKEN}
    ${split_data}=      Create Dictionary    id=${product_id}    quantity=${quantity}
    ${split_response}=  POST On Session    vkho    /products/split    json=${split_data}    headers=${headers}    expected_status=201
    ${split_json}=      Evaluate         json.loads('''${split_response.text}''')    json
    ${return_id}=       Set Variable    ${split_json}[id]
    
    ${update_data}=     Create Dictionary
    ...                 id=${return_id}
    ...                 status=RETURNED
    ...                 supplierId=${supplier_id}
    ...                 note=Returned to supplier
    ${update_response}= POST On Session    vkho    /products/update    json=${update_data}    headers=${headers}    expected_status=any
    ${update_json}=     Evaluate         json.loads('''${update_response.text}''')    json
    RETURN            ${update_response.status_code}    ${update_json}    ${return_id}

Transfer Stock
    [Arguments]         ${product_id}    ${quantity}    ${new_warehouse_id}    ${new_rack_id}
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${MANAGER_TOKEN}
    ${split_data}=      Create Dictionary    id=${product_id}    quantity=${quantity}
    ${split_response}=  POST On Session    vkho    /products/split    json=${split_data}    headers=${headers}    expected_status=201
    ${split_json}=      Evaluate         json.loads('''${split_response.text}''')    json
    ${transfer_id}=     Set Variable    ${split_json}[id]
    
    ${update_data}=     Create Dictionary
    ...                 id=${transfer_id}
    ...                 warehouseId=${new_warehouse_id}
    ...                 rackId=${new_rack_id}
    ...                 idRackReallocate=${new_rack_id}
    ...                 status=TRANSFERRED
    ${update_response}= POST On Session    vkho    /products/update    json=${update_data}    headers=${headers}    expected_status=any
    ${update_json}=     Evaluate         json.loads('''${update_response.text}''')    json
    RETURN            ${update_response.status_code}    ${update_json}    ${transfer_id}

Get Inventory
    [Arguments]         ${warehouse_id}
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${MANAGER_TOKEN}
    ${response}=        GET On Session    vkho    /products/get-inventory    params=warehouseId=${warehouse_id}    headers=${headers}    expected_status=any
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    RETURN            ${response.status_code}    ${json}

Validate Inventory Sync
    [Documentation]     Validate inventory quantities and pricing across warehouses
    [Arguments]         ${warehouse_id}    ${product_id}    ${expected_quantity}    ${expected_sale_price}
    ${status}    ${inventory}=    Get Inventory    ${warehouse_id}
    Should Be Equal As Integers    ${status}    200
    ${found}=           Set Variable    ${FALSE}
    FOR    ${item}    IN    @{inventory}
        ${item_id}=     Evaluate    str(${item}[id]) if 'id' in ${item} else None
        IF    "${item_id}" == "${product_id}"
            Should Be Equal As Integers    ${item}[totalQuantity]    ${expected_quantity}
            ...                            Quantity mismatch: ${item}[totalQuantity] vs ${expected_quantity} for ${product_id}
            Should Be Equal As Numbers     ${item}[salePrice]    ${expected_sale_price}
            ...                            Price mismatch: ${item}[salePrice] vs ${expected_sale_price} for ${product_id}
            ${found}=       Set Variable    ${TRUE}
            BREAK
        END
    END
    Should Be True    ${found}    Product ${product_id} not found in inventory

Delete Product
    [Arguments]         ${product_id}
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${MANAGER_TOKEN}
    ${response}=        DELETE On Session    vkho    /products/delete/${product_id}    headers=${headers}    expected_status=200
    RETURN            ${TRUE}

Delete MasterProduct
    [Arguments]         ${master_id}
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${MANAGER_TOKEN}
    ${response}=        DELETE On Session    vkho    /master-products/delete/${master_id}    headers=${headers}    expected_status=200
    RETURN            ${TRUE}

Delete Rack
    [Arguments]         ${rack_id}
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${MANAGER_TOKEN}
    ${response}=        DELETE On Session    vkho    /racks/delete/${rack_id}    headers=${headers}    expected_status=200
    RETURN            ${TRUE}

Delete Warehouse
    [Arguments]         ${warehouse_id}
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${MANAGER_TOKEN}
    ${response}=        DELETE On Session    vkho    /warehouses/delete/${warehouse_id}    headers=${headers}    expected_status=200
    RETURN            ${TRUE}

Delete Supplier
    [Arguments]         ${supplier_id}
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${MANAGER_TOKEN}
    ${response}=        DELETE On Session    vkho    /suppliers/delete/${supplier_id}    headers=${headers}    expected_status=200
    RETURN            ${TRUE}

*** Test Cases ***
01 - Inventory Management with Dynamic Pricing, Supplier Returns, and Synchronization
    [Documentation]     End-to-end test for inventory with dynamic pricing, returns, and multi-warehouse synchronization
    [Tags]              inventory    products    master-products    pricing    returns    sync

    Setup Manager Session
    Log                 Manager session established

    # Setup Warehouses and Racks
    ${wh1_data}=        Generate Warehouse Data    Main
    ${wh1_id}    ${wh1_response}=    Create Warehouse    ${wh1_data}
    Set Global Variable  ${TEST_WAREHOUSE1_ID}    ${wh1_id}
    ${rack1_data}=      Generate Rack Data    ${TEST_WAREHOUSE1_ID}
    ${rack1_id}    ${rack1_response}=    Create Rack    ${rack1_data}
    Set Global Variable  ${TEST_RACK1_ID}    ${rack1_id}
    Log                 Created Main Warehouse: ${TEST_WAREHOUSE1_ID}, Rack: ${TEST_RACK1_ID}

    ${wh2_data}=        Generate Warehouse Data    Backup
    ${wh2_id}    ${wh2_response}=    Create Warehouse    ${wh2_data}
    Set Global Variable  ${TEST_WAREHOUSE2_ID}    ${wh2_id}
    ${rack2_data}=      Generate Rack Data    ${TEST_WAREHOUSE2_ID}
    ${rack2_id}    ${rack2_response}=    Create Rack    ${rack2_data}
    Set Global Variable  ${TEST_RACK2_ID}    ${rack2_id}
    Log                 Created Backup Warehouse: ${TEST_WAREHOUSE2_ID}, Rack: ${TEST_RACK2_ID}

    # Setup Supplier
    ${sup_data}=        Generate Supplier Data
    ${sup_id}    ${sup_response}=    Create Supplier    ${sup_data}
    Set Global Variable  ${TEST_SUPPLIER_ID}    ${sup_id}
    Log                 Created Supplier: ${TEST_SUPPLIER_ID}

    # Positive - Create Master Products with Dynamic Pricing
    ${master1_data}=    Generate Master Product Data    ${TEST_WAREHOUSE1_ID}    [${TEST_SUPPLIER_ID}]
    ${status_m1}    ${master1_response}=    Create Master Product    ${master1_data}
    Should Be Equal As Integers    ${status_m1}    201
    Set Global Variable  ${TEST_MASTER_ID1}    ${master1_response}[id]
    Log                 Created Master Product 1: ${TEST_MASTER_ID1}

    ${master2_data}=    Generate Master Product Data    ${TEST_WAREHOUSE2_ID}    [${TEST_SUPPLIER_ID}]
    ${status_m2}    ${master2_response}=    Create Master Product    ${master2_data}
    Should Be Equal As Integers    ${status_m2}    201
    Set Global Variable  ${TEST_MASTER_ID2}    ${master2_response}[id]
    Log                 Created Master Product 2: ${TEST_MASTER_ID2}

    # Positive - Create Products
    ${prod1_data}=      Generate Product Data    ${TEST_WAREHOUSE1_ID}    ${TEST_MASTER_ID1}    ${TEST_RACK1_ID}    ${TEST_SUPPLIER_ID}
    ${status_p1}    ${prod1_response}=    Create Product    ${prod1_data}
    Should Be Equal As Integers    ${status_p1}    201
    Set Global Variable  ${TEST_PRODUCT_ID1}    ${prod1_response}[id]
    Log                 Created Product 1: ${TEST_PRODUCT_ID1}

    ${prod2_data}=      Generate Product Data    ${TEST_WAREHOUSE1_ID}    ${TEST_MASTER_ID1}    ${TEST_RACK1_ID}    ${TEST_SUPPLIER_ID}    3000
    ${status_p2}    ${prod2_response}=    Create Product    ${prod2_data}
    Should Be Equal As Integers    ${status_p2}    201
    Set Global Variable  ${TEST_PRODUCT_ID2}    ${prod2_response}[id]
    Log                 Created Product 2: ${TEST_PRODUCT_ID2}

    # Negative - Invalid Pricing in Master Product
    ${invalid_price_data}=    Generate Master Product Data    ${TEST_WAREHOUSE1_ID}    [${TEST_SUPPLIER_ID}]    -10.00    100.00    120.00
    ${status_m3}    ${master3_response}=    Create Master Product    ${invalid_price_data}
    Should Be Equal As Integers    ${status_m3}    400
    Should Contain    ${master3_response}[message]    purchasePrice    ignore_case=True
    Log                 Prevented creation with negative purchasePrice

    # Missing Parameter - No salePrice in Product
    ${no_price_data}=    Generate Product Data    ${TEST_WAREHOUSE1_ID}    ${TEST_MASTER_ID1}    ${TEST_RACK1_ID}    ${TEST_SUPPLIER_ID}
    Remove From Dictionary    ${no_price_data}    salePrice
    ${status_p3}    ${prod3_response}=    Create Product    ${no_price_data}
    Should Be Equal As Integers    ${status_p3}    400
    Should Contain    ${prod3_response}[message]    salePrice    ignore_case=True
    Log                 Prevented creation without salePrice

    # Positive - Assign Products to Rack
    ${status_rack1}    ${rack1_response}=    Add Product To Rack    ${TEST_RACK1_ID}    [${TEST_PRODUCT_ID1}, ${TEST_PRODUCT_ID2}]
    Should Be Equal As Integers    ${status_rack1}    201
    Log                 Assigned Products to Rack ${TEST_RACK1_ID}

    # Positive - Update Master Pricing
    ${status_mp1}    ${mp1_response}=    Update Master Pricing    ${TEST_MASTER_ID1}    60.00    120.00    140.00
    Should Be Equal As Integers    ${status_mp1}    201
    Log                 Updated Master Product 1 pricing

    # Positive - Update Product Pricing
    ${status_upd1}    ${upd1_response}=    Update Product Pricing    ${TEST_PRODUCT_ID1}    60.00    120.00
    Should Be Equal As Integers    ${status_upd1}    201
    Log                 Updated Product 1 pricing to match master

    # Edge Case - Maximum Pricing
    ${status_upd2}    ${upd2_response}=    Update Product Pricing    ${TEST_PRODUCT_ID2}    ${MAX_PRICE}    ${MAX_PRICE}
    Should Be Equal As Integers    ${status_upd2}    201
    Log                 Updated Product 2 to maximum pricing

    # Negative - Exceed Maximum Pricing
    ${status_upd3}    ${upd3_response}=    Update Product Pricing    ${TEST_PRODUCT_ID2}    ${MAX_PRICE + 1}    ${MAX_PRICE + 1}
    Should Be Equal As Integers    ${status_upd3}    400
    Should Contain    ${upd3_response}[message]    cost    ignore_case=True
    Log                 Prevented update exceeding maximum price

    # Positive - Process Supplier Return
    ${status_ret1}    ${ret1_response}    ${return_id}=    Process Supplier Return    ${TEST_PRODUCT_ID1}    500    ${TEST_SUPPLIER_ID}
    Should Be Equal As Integers    ${status_ret1}    201
    Set Global Variable  ${TEST_RETURN_ID}    ${return_id}
    Log                 Processed supplier return: ${TEST_RETURN_ID} with 500 units

    # Negative - Return with Invalid Supplier
    ${status_ret2}    ${ret2_response}    ${dummy_id}=    Process Supplier Return    ${TEST_PRODUCT_ID2}    1000    9999
    Should Be Equal As Integers    ${status_ret2}    400
    Should Contain    ${ret2_response}[message]    supplierId    ignore_case=True
    Log                 Prevented return with invalid supplierId

    # Edge Case - Return Zero Quantity
    ${status_ret3}    ${ret3_response}    ${dummy_id}=    Process Supplier Return    ${TEST_PRODUCT_ID2}    0    ${TEST_SUPPLIER_ID}
    Should Be Equal As Integers    ${status_ret3}    400
    Should Contain    ${ret3_response}[message]    quantity    ignore_case=True
    Log                 Prevented return of zero quantity

    # Missing Parameter - Return without Quantity
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${MANAGER_TOKEN}
    ${no_qty_data}=     Create Dictionary    id=${TEST_PRODUCT_ID1}
    ${response}=        POST On Session    vkho    /products/split    json=${no_qty_data}    headers=${headers}    expected_status=400
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    Should Contain    ${json}[message]    quantity    ignore_case=True
    Log                 Prevented return without quantity

    # Positive - Transfer Stock
    ${status_t1}    ${t1_response}    ${transfer_id}=    Transfer Stock    ${TEST_PRODUCT_ID2}    1500    ${TEST_WAREHOUSE2_ID}    ${TEST_RACK2_ID}
    Should Be Equal As Integers    ${status_t1}    201
    Set Global Variable  ${TEST_TRANSFER_ID}    ${transfer_id}
    Log                 Transferred 1500 units to ${TEST_TRANSFER_ID} in Warehouse 2

    # Edge Case - Transfer Full Quantity
    ${status_t2}    ${t2_response}    ${full_transfer_id}=    Transfer Stock    ${TEST_PRODUCT_ID2}    1500    ${TEST_WAREHOUSE2_ID}    ${TEST_RACK2_ID}
    Should Be Equal As Integers    ${status_t2}    201    # Assuming remaining 1500 is valid
    Log                 Transferred remaining 1500 units from Product 2

    # Positive - Validate Inventory Synchronization
    Validate Inventory Sync    ${TEST_WAREHOUSE1_ID}    ${TEST_PRODUCT_ID1}    1500    120.00    # 2000 - 500 returned
    Validate Inventory Sync    ${TEST_WAREHOUSE1_ID}    ${TEST_PRODUCT_ID2}    0       ${MAX_PRICE}  # All transferred
    Validate Inventory Sync    ${TEST_WAREHOUSE2_ID}    ${TEST_TRANSFER_ID}    1500    ${MAX_PRICE}
    Validate Inventory Sync    ${TEST_WAREHOUSE2_ID}    ${full_transfer_id}    1500    ${MAX_PRICE}
    Log                 Validated inventory synchronization across warehouses

    # Negative - Unauthorized Pricing Update
    ${no_auth_headers}=    Create Dictionary    Content-Type=application/json
    ${price_data}=         Create Dictionary    id=${TEST_PRODUCT_ID1}    cost=70.00    salePrice=130.00    status=STOCKED
    ${response}=           POST On Session    vkho    /products/update    json=${price_data}    headers=${no_auth_headers}    expected_status=401
    ${json}=               Evaluate         json.loads('''${response.text}''')    json
    Should Contain    ${json}[message]    authorization    ignore_case=True
    Log                 Prevented unauthorized pricing update

    # Edge Case - Minimum Pricing
    ${status_upd4}    ${upd4_response}=    Update Product Pricing    ${TEST_PRODUCT_ID1}    ${MIN_PRICE}    ${MIN_PRICE}
    Should Be Equal As Integers    ${status_upd4}    201
    Validate Inventory Sync    ${TEST_WAREHOUSE1_ID}    ${TEST_PRODUCT_ID1}    1500    ${MIN_PRICE}
    Log                 Updated Product 1 to minimum pricing and validated

    # Cleanup
    Delete Product    ${TEST_PRODUCT_ID1}
    Delete Product    ${TEST_PRODUCT_ID2}
    Delete Product    ${TEST_RETURN_ID}
    Delete Product    ${TEST_TRANSFER_ID}
    Delete Product    ${full_transfer_id}
    Delete MasterProduct    ${TEST_MASTER_ID1}
    Delete MasterProduct    ${TEST_MASTER_ID2}
    Delete Rack    ${TEST_RACK1_ID}
    Delete Rack    ${TEST_RACK2_ID}
    Delete Warehouse    ${TEST_WAREHOUSE1_ID}
    Delete Warehouse    ${TEST_WAREHOUSE2_ID}
    Delete Supplier    ${TEST_SUPPLIER_ID}
    Log                 Cleaned up all test resources