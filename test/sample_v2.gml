<?xml version="1.0" encoding="UTF-8"?>
<gml:FeatureCollection 
    xmlns:egb="ewidencjaGruntowIBudynkow:1.0" 
    xmlns:gml="http://www.opengis.net/gml/3.2" 
    xmlns:xlink="http://www.w3.org/1999/xlink">

    <gml:featureMember>
        <egb:EGB_DzialkaEwidencyjna gml:id="DZ.2">
            <egb:idDzialki>221208_2.0026.60/6</egb:idDzialki>
            <egb:numerKW>SL1S/00075286/4</egb:numerKW>
            <egb:poleEwidencyjne>0.1000</egb:poleEwidencyjne>
            
            <egb:JRG2 xlink:href="#JRG.2"/>

            <egb:punktGraniczny xlink:href="#P.10"/>
            
        </egb:EGB_DzialkaEwidencyjna>
    </gml:featureMember>

    <gml:featureMember>
        <egb:EGB_PunktGraniczny gml:id="P.10">
            <egb:geometria>
                <gml:Point gml:id="P.10_GEO">
                    <gml:pos>6042040.56 6433056.02</gml:pos>
                </gml:Point>
            </egb:geometria>
            <egb:idPunktu>D.221208_2.0026.367</egb:idPunktu>
            <egb:oznWMaterialeZrodlowym>340</egb:oznWMaterialeZrodlowym>
            <egb:numerOperatuTechnicznego>P.2212.2002.1003</egb:numerOperatuTechnicznego>
        </egb:EGB_PunktGraniczny>
    </gml:featureMember>

    <gml:featureMember>
        <egb:EGB_JednostkaRejestrowaGruntow gml:id="JRG.2">
            <egb:idJednostkiRejestrowej>G.200</egb:idJednostkiRejestrowej>
        </egb:EGB_JednostkaRejestrowaGruntow>
    </gml:featureMember>

    <gml:featureMember>
        <egb:EGB_OsobaFizyczna gml:id="OS.20">
            <egb:pierwszeImie>Czesław</egb:pierwszeImie>
            <egb:pierwszyCzlonNazwiska>Bazyk</egb:pierwszyCzlonNazwiska>
        </egb:EGB_OsobaFizyczna>
    </gml:featureMember>

    <gml:featureMember>
        <egb:EGB_UdzialWeWlasnosci gml:id="UDZ.201">
            <egb:licznikUlamkaOkreslajacegoWartoscUdzialu>3</egb:licznikUlamkaOkreslajacegoWartoscUdzialu>
            <egb:mianownikUlamkaOkreslajacegoWartoscUdzialu>4</egb:mianownikUlamkaOkreslajacegoWartoscUdzialu>
            
            <egb:przedmiotUdzialuWlasnosci>
                <egb:EGB_JednostkaRejestrowa>
                    <egb:JRG xlink:href="#JRG.2"/>
                </egb:EGB_JednostkaRejestrowa>
            </egb:przedmiotUdzialuWlasnosci>

            <egb:podmiotUdzialuWlasnosci>
                <egb:EGB_Podmiot>
                    <egb:osobaFizyczna xlink:href="#OS.20"/>
                </egb:EGB_Podmiot>
            </egb:podmiotUdzialuWlasnosci>
        </egb:EGB_UdzialWeWlasnosci>
    </gml:featureMember>

</gml:FeatureCollection>

