xquery version "3.1";

import module namespace models="http://exist.jmmc.fr/datamodels/models" at "models.xql";

  
    let $group-by-attr := request:get-parameter("group-by", "ucd")
    
    let $votables-map := map:merge( for $name in map:keys($models:models)
        let $model := $models:models($name)
        let $type := models:get-type($model)
        let $url := $type ! $model(.)
        return switch ($type) case "tap" case "votable" return map{$name : models:get-votable($model)} default return ()
        )
    let $table-names := map:keys($votables-map)
    let $votables:= $table-names ! $votables-map(.)
    let $fields-attrs := distinct-values($votables//*:FIELD/@*!name())
    let $columns := $votables//*:FIELD    
    return
        <fields>{
        for $field in map:for-each($votables-map, function ($k, $v){$v//*:FIELD}) group by $col-name := data($field/@*[name()=$group-by-attr])
                order by $col-name
                return 
                    <field key="{$col-name}">
                        { 
                            for $attr in $fields-attrs 
                                for $value in  distinct-values($field/@*[name(.)=$attr])
                                    return 
                                        element {$attr} { $value }
                            ,
                            for $desc in distinct-values($field/*:DESCRIPTION)
                            return 
                                element {"description"} {data($desc)}
                                
                    }
                    <apps>{   string-join((
                        for $name in $table-names let $votable:=$votables-map($name) 
                        return 
                            if($name[$col-name=$votable//*:FIELD/@*[name()=$group-by-attr]]) then $name else ()
                        ),",")
                    }</apps>
                    </field>
            }</fields>
